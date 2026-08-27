import bcrypt from 'bcryptjs';
import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import { randomInt } from 'node:crypto';
import { ObjectId } from 'mongodb';
import { googleClientIds, jwtDias, jwtSecret } from './env.mjs';
import { partidas, recuperacionesPendientes, registrosPendientes, usuarios } from './db.mjs';
import { JUEGO_GLOBAL, JUEGOS, juegoValido, puntosVacios } from './juegos.mjs';
import { enviarCodigoRegistro } from './mail.mjs';

const RONDAS_HASH = 10;
const TTL_MS = 15 * 60 * 1000;
const googleOAuth = new OAuth2Client();

export function publico(doc) {
  if (!doc) return null;
  const puntos = { ...puntosVacios(), ...(doc.puntos || {}) };
  const nombreUsuario = doc.nombreUsuario || doc.nombre || '';
  const monedas = Number.isFinite(Number(doc.monedas))
    ? Math.max(0, Math.floor(Number(doc.monedas)))
    : 0;
  return {
    id: String(doc._id),
    nombreUsuario,
    nombre: nombreUsuario,
    email: doc.email,
    puntos,
    monedas,
    creadoEn: doc.creadoEn,
  };
}

/** Bienvenida: 100 monedas la primera vez (registro o usuarios viejos sin campo). */
export async function asegurarMonedasIniciales(doc) {
  if (doc == null) return doc;
  if (Number.isFinite(Number(doc.monedas))) return doc;
  const actualizado = await usuarios().findOneAndUpdate(
    { _id: doc._id, monedas: { $exists: false } },
    { $set: { monedas: 100, monedasOtorgadasEn: new Date() } },
    { returnDocument: 'after' },
  );
  const actual =
    actualizado && actualizado.value !== undefined
      ? actualizado.value
      : actualizado;
  return actual || { ...doc, monedas: 100 };
}

export function firmar(usuarioId) {
  return jwt.sign({ sub: String(usuarioId) }, jwtSecret, {
    expiresIn: `${jwtDias}d`,
  });
}

export function leerToken(req) {
  const raw = req.headers.authorization || '';
  const token = raw.startsWith('Bearer ') ? raw.slice(7) : '';
  if (!token) return null;
  try {
    return jwt.verify(token, jwtSecret);
  } catch {
    return null;
  }
}

export async function exigirUsuario(req, res, next) {
  const payload = leerToken(req);
  if (!payload?.sub) {
    res.status(401).json({ error: 'Tenés que iniciar sesión.' });
    return;
  }
  let _id;
  try {
    _id = new ObjectId(String(payload.sub));
  } catch {
    res.status(401).json({ error: 'Sesión inválida.' });
    return;
  }
  const doc = await usuarios().findOne({ _id });
  if (!doc) {
    res.status(401).json({ error: 'Usuario no encontrado.' });
    return;
  }
  req.usuario = doc;
  next();
}

function emailOk(email) {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

function usuarioOk(nombre) {
  return /^[A-Za-z0-9_]{3,20}$/.test(nombre);
}

function formatoNombreUsuario(nombre) {
  const t = String(nombre || '').trim();
  if (!t) return t;
  return t.charAt(0).toUpperCase() + t.slice(1).toLowerCase();
}

export async function registrar(req, res) {
  const nombreUsuario = formatoNombreUsuario(
    req.body?.nombreUsuario || req.body?.nombre,
  );
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');

  if (!usuarioOk(nombreUsuario)) {
    res.status(400).json({
      error:
        'El usuario tiene que tener 3 a 20 caracteres: letras, números o _.',
    });
    return;
  }
  if (!emailOk(email)) {
    res.status(400).json({ error: 'El email no es válido.' });
    return;
  }
  if (password.length < 6) {
    res.status(400).json({ error: 'La contraseña tiene que tener al menos 6 caracteres.' });
    return;
  }

  const nombreNorm = nombreUsuario.toLowerCase();
  const yaUser = await usuarios().findOne({
    $or: [{ email }, { nombreUsuarioNorm: nombreNorm }],
  });
  if (yaUser) {
    const cual =
      yaUser.email === email
        ? 'Ese email ya está registrado.'
        : 'Ese nombre de usuario ya está en uso.';
    res.status(409).json({ error: cual });
    return;
  }

  const codigo = String(randomInt(0, 1_000_000)).padStart(6, '0');
  const ahora = new Date();
  const expiraEn = new Date(ahora.getTime() + TTL_MS);

  await registrosPendientes().deleteMany({
    $or: [{ email }, { nombreUsuarioNorm: nombreNorm }],
  });
  await registrosPendientes().insertOne({
    nombreUsuario,
    nombreUsuarioNorm: nombreNorm,
    email,
    passwordHash: await bcrypt.hash(password, RONDAS_HASH),
    codigoHash: await bcrypt.hash(codigo, RONDAS_HASH),
    creadoEn: ahora,
    expiraEn,
  });

  try {
    await enviarCodigoRegistro({ email, codigo });
  } catch (e) {
    console.error(e);
    await registrosPendientes().deleteMany({ email });
    res.status(502).json({
      error:
        'No se pudo enviar el mail. Revisá RESEND_API_KEY en backend/mongo/.env.',
    });
    return;
  }

  res.status(201).json({
    ok: true,
    email,
    expiraEn: expiraEn.toISOString(),
    minutos: 15,
  });
}

export async function reenviar(req, res) {
  const email = String(req.body?.email || '').trim().toLowerCase();
  if (!emailOk(email)) {
    res.status(400).json({ error: 'El email no es válido.' });
    return;
  }
  const pend = await registrosPendientes().findOne({ email });
  if (!pend) {
    res.status(400).json({ error: 'No hay un registro pendiente. Registráte de nuevo.' });
    return;
  }
  const codigo = String(randomInt(0, 1_000_000)).padStart(6, '0');
  const expiraEn = new Date(Date.now() + TTL_MS);
  await registrosPendientes().updateOne(
    { _id: pend._id },
    {
      $set: {
        codigoHash: await bcrypt.hash(codigo, RONDAS_HASH),
        expiraEn,
      },
    },
  );
  try {
    await enviarCodigoRegistro({ email, codigo });
  } catch (e) {
    console.error(e);
    res.status(502).json({ error: 'No se pudo enviar el mail.' });
    return;
  }
  res.json({ ok: true, email, expiraEn: expiraEn.toISOString(), minutos: 15 });
}

export async function verificar(req, res) {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const codigo = String(req.body?.codigo || '').trim();
  if (!emailOk(email) || !/^\d{6}$/.test(codigo)) {
    res.status(400).json({ error: 'Ingresá el código de 6 dígitos.' });
    return;
  }

  const pend = await registrosPendientes().findOne({ email });
  if (!pend || new Date(pend.expiraEn).getTime() < Date.now()) {
    if (pend) await registrosPendientes().deleteOne({ _id: pend._id });
    res.status(400).json({ error: 'El código expiró o no existe. Registráte de nuevo.' });
    return;
  }
  const ok = await bcrypt.compare(codigo, pend.codigoHash || '');
  if (!ok) {
    res.status(401).json({ error: 'El código no es correcto.' });
    return;
  }

  const ahora = new Date();
  const doc = {
    nombreUsuario: pend.nombreUsuario,
    nombreUsuarioNorm: pend.nombreUsuarioNorm,
    nombre: pend.nombreUsuario,
    email: pend.email,
    passwordHash: pend.passwordHash,
    puntos: puntosVacios(),
    monedas: 100,
    monedasOtorgadasEn: ahora,
    creadoEn: ahora,
    verificadoEn: ahora,
  };

  let insertedId;
  try {
    const r = await usuarios().insertOne(doc);
    insertedId = r.insertedId;
  } catch (e) {
    if (e?.code === 11000) {
      res.status(409).json({ error: 'Ese usuario o email ya está registrado.' });
      return;
    }
    throw e;
  }
  await registrosPendientes().deleteOne({ _id: pend._id });
  doc._id = insertedId;
  res.status(201).json({ token: firmar(insertedId), usuario: publico(doc) });
}

export async function login(req, res) {
  const clave = String(req.body?.usuario || req.body?.email || '').trim();
  const password = String(req.body?.password || '');
  if (!clave || !password) {
    res.status(400).json({ error: 'Ingresá usuario o email, y la contraseña.' });
    return;
  }
  const lower = clave.toLowerCase();
  const doc = await usuarios().findOne({
    $or: [{ email: lower }, { nombreUsuarioNorm: lower }],
  });
  if (!doc) {
    res.status(401).json({ error: 'Usuario o contraseña incorrectos.' });
    return;
  }
  if (!doc.passwordHash) {
    res.status(401).json({
      error:
        'Esta cuenta se creó con Google. Usá “Iniciar sesión con Google”.',
    });
    return;
  }
  if (!(await bcrypt.compare(password, doc.passwordHash))) {
    res.status(401).json({ error: 'Usuario o contraseña incorrectos.' });
    return;
  }
  const conMonedas = await asegurarMonedasIniciales(doc);
  res.json({ token: firmar(conMonedas._id), usuario: publico(conMonedas) });
}

async function nombreUsuarioLibreDesdeGoogle(payload) {
  const emailLocal = String(payload.email || '')
    .split('@')[0]
    .replace(/[^A-Za-z0-9_]/g, '');
  const desdeNombre = String(payload.name || '')
    .replace(/[^A-Za-z0-9_]/g, '');
  let base = formatoNombreUsuario(desdeNombre || emailLocal || 'Jugador');
  if (base.length < 3) base = 'Jugador';
  if (base.length > 16) base = base.slice(0, 16);

  for (let i = 0; i < 40; i++) {
    const candidato =
      i === 0 ? base : formatoNombreUsuario(`${base}${i}`.slice(0, 20));
    if (!usuarioOk(candidato)) continue;
    const existe = await usuarios().findOne({
      nombreUsuarioNorm: candidato.toLowerCase(),
    });
    if (!existe) return candidato;
  }
  return formatoNombreUsuario(`G${Date.now().toString(36)}`.slice(0, 20));
}

/** Login / registro con Google (mismo endpoint para ambos botones). */
export async function loginConGoogle(req, res) {
  if (googleClientIds.length === 0) {
    res.status(503).json({
      error:
        'Google Sign-In no está configurado. Falta GOOGLE_CLIENT_IDS en el servidor.',
    });
    return;
  }

  const idToken = String(req.body?.idToken || '').trim();
  if (!idToken) {
    res.status(400).json({ error: 'Falta el token de Google.' });
    return;
  }

  let payload;
  try {
    const ticket = await googleOAuth.verifyIdToken({
      idToken,
      audience: googleClientIds,
    });
    payload = ticket.getPayload();
  } catch (e) {
    console.error('Google token inválido:', e?.message || e);
    res.status(401).json({ error: 'No se pudo verificar la cuenta de Google.' });
    return;
  }

  const googleId = payload?.sub ? String(payload.sub) : '';
  const email = String(payload?.email || '')
    .trim()
    .toLowerCase();
  if (!googleId || !emailOk(email)) {
    res.status(400).json({ error: 'La cuenta de Google no trajo un email válido.' });
    return;
  }
  if (payload.email_verified === false) {
    res.status(401).json({ error: 'Verificá tu email en Google e intentá de nuevo.' });
    return;
  }

  let doc =
    (await usuarios().findOne({ googleId })) ||
    (await usuarios().findOne({ email }));

  if (doc) {
    const patch = {};
    if (!doc.googleId) patch.googleId = googleId;
    if (!doc.authProviders?.includes?.('google')) {
      const prev = Array.isArray(doc.authProviders) ? doc.authProviders : [];
      if (doc.passwordHash && !prev.includes('password')) prev.push('password');
      if (!prev.includes('google')) prev.push('google');
      patch.authProviders = prev;
    }
    if (Object.keys(patch).length > 0) {
      await usuarios().updateOne({ _id: doc._id }, { $set: patch });
      doc = { ...doc, ...patch };
    }
  } else {
    const ahora = new Date();
    const nombreUsuario = await nombreUsuarioLibreDesdeGoogle(payload);
    const nuevo = {
      nombreUsuario,
      nombreUsuarioNorm: nombreUsuario.toLowerCase(),
      nombre: nombreUsuario,
      email,
      googleId,
      authProviders: ['google'],
      puntos: puntosVacios(),
      monedas: 100,
      monedasOtorgadasEn: ahora,
      creadoEn: ahora,
      verificadoEn: ahora,
    };
    try {
      const r = await usuarios().insertOne(nuevo);
      nuevo._id = r.insertedId;
      doc = nuevo;
    } catch (e) {
      if (e?.code === 11000) {
        doc = await usuarios().findOne({ email });
        if (!doc) {
          res.status(409).json({ error: 'No se pudo crear la cuenta. Probá de nuevo.' });
          return;
        }
      } else {
        throw e;
      }
    }
  }

  const conMonedas = await asegurarMonedasIniciales(doc);
  res.json({ token: firmar(conMonedas._id), usuario: publico(conMonedas) });
}

async function guardarCodigoRecuperacion(email) {
  const codigo = String(randomInt(0, 1_000_000)).padStart(6, '0');
  const ahora = new Date();
  const expiraEn = new Date(ahora.getTime() + TTL_MS);
  await recuperacionesPendientes().deleteMany({ email });
  await recuperacionesPendientes().insertOne({
    email,
    codigoHash: await bcrypt.hash(codigo, RONDAS_HASH),
    verificado: false,
    creadoEn: ahora,
    expiraEn,
  });
  await enviarCodigoRegistro({ email, codigo });
  return expiraEn;
}

export async function pedirRecuperacion(req, res) {
  const email = String(req.body?.email || '').trim().toLowerCase();
  if (!emailOk(email)) {
    res.status(400).json({ error: 'El email no es válido.' });
    return;
  }
  const doc = await usuarios().findOne({ email });
  if (!doc) {
    res.status(404).json({ error: 'Ese email no está registrado.' });
    return;
  }
  if (!doc.passwordHash) {
    res.status(400).json({
      error:
        'Esta cuenta usa Google. Entrá con “Iniciar sesión con Google”; no hay contraseña para recuperar.',
    });
    return;
  }
  try {
    const expiraEn = await guardarCodigoRecuperacion(email);
    res.json({
      ok: true,
      email,
      expiraEn: expiraEn.toISOString(),
      minutos: 15,
    });
  } catch (e) {
    console.error(e);
    await recuperacionesPendientes().deleteMany({ email });
    res.status(502).json({
      error:
        'No se pudo enviar el mail. Revisá RESEND_API_KEY en backend/mongo/.env.',
    });
  }
}

export async function reenviarRecuperacion(req, res) {
  const email = String(req.body?.email || '').trim().toLowerCase();
  if (!emailOk(email)) {
    res.status(400).json({ error: 'El email no es válido.' });
    return;
  }
  const pend = await recuperacionesPendientes().findOne({ email });
  if (!pend) {
    res.status(400).json({ error: 'Pedí primero el código de recuperación.' });
    return;
  }
  try {
    const expiraEn = await guardarCodigoRecuperacion(email);
    res.json({
      ok: true,
      email,
      expiraEn: expiraEn.toISOString(),
      minutos: 15,
    });
  } catch (e) {
    console.error(e);
    await recuperacionesPendientes().deleteMany({ email });
    res.status(502).json({ error: 'No se pudo enviar el mail.' });
  }
}

export async function verificarRecuperacion(req, res) {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const codigo = String(req.body?.codigo || '').trim();
  if (!emailOk(email) || !/^\d{6}$/.test(codigo)) {
    res.status(400).json({ error: 'Ingresá el código de 6 dígitos.' });
    return;
  }
  const pend = await recuperacionesPendientes().findOne({ email });
  if (!pend || new Date(pend.expiraEn).getTime() < Date.now()) {
    if (pend) await recuperacionesPendientes().deleteOne({ _id: pend._id });
    res.status(400).json({ error: 'El código expiró o no existe. Pedilo de nuevo.' });
    return;
  }
  const ok = await bcrypt.compare(codigo, pend.codigoHash || '');
  if (!ok) {
    res.status(401).json({ error: 'El código no es correcto.' });
    return;
  }
  await recuperacionesPendientes().updateOne(
    { _id: pend._id },
    { $set: { verificado: true } },
  );
  res.json({ ok: true, email });
}

export async function restablecerClave(req, res) {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const password = String(req.body?.password || '');
  if (!emailOk(email)) {
    res.status(400).json({ error: 'El email no es válido.' });
    return;
  }
  if (password.length < 6) {
    res.status(400).json({ error: 'La contraseña tiene que tener al menos 6 caracteres.' });
    return;
  }
  const pend = await recuperacionesPendientes().findOne({ email, verificado: true });
  if (!pend || new Date(pend.expiraEn).getTime() < Date.now()) {
    if (pend) await recuperacionesPendientes().deleteOne({ _id: pend._id });
    res.status(400).json({ error: 'El código expiró. Pedí recuperar de nuevo.' });
    return;
  }
  const actualizado = await usuarios().updateOne(
    { email },
    {
      $set: {
        passwordHash: await bcrypt.hash(password, RONDAS_HASH),
        actualizadoEn: new Date(),
      },
    },
  );
  await recuperacionesPendientes().deleteMany({ email });
  if (!actualizado.matchedCount) {
    res.status(404).json({ error: 'Usuario no encontrado.' });
    return;
  }
  res.json({ ok: true });
}

export async function yo(req, res) {
  const conMonedas = await asegurarMonedasIniciales(req.usuario);
  res.json({ usuario: publico(conMonedas) });
}

/** +3 monedas y +3 puntos de ranking por ganar vs PC (solo con sesión). */
export async function sumarMonedasVictoriaPc(req, res) {
  const juegoId = String(req.body?.juegoId || '');
  await asegurarMonedasIniciales(req.usuario);

  const inc = { monedas: 3 };
  if (juegoValido(juegoId) && juegoId !== JUEGO_GLOBAL) {
    inc[`puntos.${juegoId}`] = 3;
    inc[`puntos.${JUEGO_GLOBAL}`] = 3;
  }

  const actualizado = await usuarios().findOneAndUpdate(
    { _id: req.usuario._id },
    {
      $inc: inc,
      $set: { actualizadoEn: new Date() },
    },
    { returnDocument: 'after' },
  );
  const actual =
    actualizado && actualizado.value !== undefined
      ? actualizado.value
      : actualizado;
  if (!actual) {
    res.status(404).json({ error: 'Usuario no encontrado.' });
    return;
  }
  await partidas().insertOne({
    usuarioId: req.usuario._id,
    tipo: 'victoriaPc',
    juegoId: juegoValido(juegoId) ? juegoId : undefined,
    monedas: 3,
    puntos: juegoValido(juegoId) && juegoId !== JUEGO_GLOBAL ? 3 : 0,
    fecha: new Date(),
  });
  res.json({
    usuario: publico(actual),
    monedasSumadas: 3,
    puntosSumados: juegoValido(juegoId) && juegoId !== JUEGO_GLOBAL ? 3 : 0,
  });
}

export async function sumarPuntos(req, res) {
  const juegoId = String(req.body?.juegoId || '');
  const puntos = Number(req.body?.puntos);
  if (!juegoValido(juegoId) || juegoId === JUEGO_GLOBAL) {
    res.status(400).json({ error: 'Juego no válido.' });
    return;
  }
  if (!Number.isFinite(puntos) || puntos === 0) {
    res.status(400).json({ error: 'Los puntos tienen que ser un número distinto de 0.' });
    return;
  }

  const campoJuego = `puntos.${juegoId}`;
  const campoGlobal = `puntos.${JUEGO_GLOBAL}`;
  const actualizado = await usuarios().findOneAndUpdate(
    { _id: req.usuario._id },
    {
      $inc: { [campoJuego]: puntos, [campoGlobal]: puntos },
      $set: { actualizadoEn: new Date() },
    },
    { returnDocument: 'after' },
  );
  const actual = actualizado && actualizado.value !== undefined
    ? actualizado.value
    : actualizado;
  if (!actual) {
    res.status(404).json({ error: 'Usuario no encontrado.' });
    return;
  }

  await partidas().insertOne({
    usuarioId: req.usuario._id,
    juegoId,
    puntos,
    fecha: new Date(),
  });

  res.json({ usuario: publico(actual) });
}

export async function ranking(req, res) {
  const juego = String(req.query?.juego || JUEGO_GLOBAL);
  const limite = Math.min(100, Math.max(1, Number(req.query?.limite) || 50));
  if (!juegoValido(juego)) {
    res.status(400).json({ error: 'Juego no válido.' });
    return;
  }
  const campo = `puntos.${juego}`;
  const lista = await usuarios()
    .find({ [campo]: { $gt: 0 } })
    .project({ nombre: 1, nombreUsuario: 1, email: 1, puntos: 1 })
    .sort({ [campo]: -1, nombreUsuario: 1 })
    .limit(limite)
    .toArray();

  res.json({
    juego,
    ranking: lista.map((doc, i) => ({
      puesto: i + 1,
      id: String(doc._id),
      nombre: doc.nombreUsuario || doc.nombre,
      puntos: Number(doc.puntos?.[juego] || 0),
    })),
  });
}

export { JUEGOS };
