import { ObjectId } from 'mongodb';
import { apuestas, partidas, usuarios } from './db.mjs';
import { JUEGO_GLOBAL, juegoValido } from './juegos.mjs';
import { asegurarMonedasIniciales, publico } from './usuarios.mjs';

const MONTOS_OK = new Set([0, 5, 10, 25, 50, 100, 250, 500, 1000]);

function montoOk(n) {
  return Number.isFinite(n) && MONTOS_OK.has(n);
}

/**
 * Retiene monedas al crear/unirse a una sala con apuesta.
 * Body: { codigoSala, monto, juegoId }
 */
export async function retenerApuesta(req, res) {
  const codigoSala = String(req.body?.codigoSala || '')
    .trim()
    .toUpperCase();
  const monto = Math.floor(Number(req.body?.monto));
  const juegoId = String(req.body?.juegoId || '');
  if (!codigoSala || codigoSala.length !== 6) {
    res.status(400).json({ error: 'Código de sala inválido.' });
    return;
  }
  if (!montoOk(monto) || monto <= 0) {
    res.status(400).json({ error: 'Monto de apuesta no válido.' });
    return;
  }
  if (!juegoValido(juegoId) || juegoId === JUEGO_GLOBAL) {
    res.status(400).json({ error: 'Juego no válido.' });
    return;
  }

  await asegurarMonedasIniciales(req.usuario);

  const existente = await apuestas().findOne({
    codigoSala,
    usuarioId: req.usuario._id,
    estado: 'retenida',
  });
  if (existente) {
    res.json({
      ok: true,
      yaRetenida: true,
      usuario: publico(req.usuario),
      monto: existente.monto,
    });
    return;
  }

  const monedas = Number(req.usuario.monedas) || 0;
  if (monedas < monto) {
    res.status(400).json({
      error: `Necesitás ${monto} monedas (tenés ${monedas}).`,
    });
    return;
  }

  const actualizado = await usuarios().findOneAndUpdate(
    { _id: req.usuario._id, monedas: { $gte: monto } },
    {
      $inc: { monedas: -monto },
      $set: { actualizadoEn: new Date() },
    },
    { returnDocument: 'after' },
  );
  const actual =
    actualizado && actualizado.value !== undefined
      ? actualizado.value
      : actualizado;
  if (!actual) {
    res.status(400).json({ error: 'No te alcanzan las monedas.' });
    return;
  }

  await apuestas().insertOne({
    codigoSala,
    usuarioId: req.usuario._id,
    nombreUsuario: actual.nombreUsuario || actual.nombre || '',
    juegoId,
    monto,
    estado: 'retenida',
    creadoEn: new Date(),
  });

  res.json({ ok: true, usuario: publico(actual), monto });
}

/** Devuelve la apuesta retenida de esta sala (si salís del lobby). */
export async function reembolsarApuesta(req, res) {
  const codigoSala = String(req.body?.codigoSala || '')
    .trim()
    .toUpperCase();
  if (!codigoSala) {
    res.status(400).json({ error: 'Falta el código de sala.' });
    return;
  }

  const apuesta = await apuestas().findOne({
    codigoSala,
    usuarioId: req.usuario._id,
    estado: 'retenida',
  });
  if (!apuesta) {
    const doc = await usuarios().findOne({ _id: req.usuario._id });
    res.json({ ok: true, reembolsado: false, usuario: publico(doc) });
    return;
  }

  const actualizado = await usuarios().findOneAndUpdate(
    { _id: req.usuario._id },
    {
      $inc: { monedas: apuesta.monto },
      $set: { actualizadoEn: new Date() },
    },
    { returnDocument: 'after' },
  );
  const actual =
    actualizado && actualizado.value !== undefined
      ? actualizado.value
      : actualizado;

  await apuestas().updateOne(
    { _id: apuesta._id },
    { $set: { estado: 'reembolsada', reembolsadaEn: new Date() } },
  );

  res.json({
    ok: true,
    reembolsado: true,
    monto: apuesta.monto,
    usuario: publico(actual),
  });
}

/**
 * El ganador cobra el pozo (suma de apuestas retenidas) en monedas
 * y suma esa misma cantidad al ranking del juego.
 * Body: { codigoSala, juegoId }
 * Solo el usuario autenticado (ganador) debe llamar esto.
 */
export async function resolverApuesta(req, res) {
  const codigoSala = String(req.body?.codigoSala || '')
    .trim()
    .toUpperCase();
  const juegoId = String(req.body?.juegoId || '');
  if (!codigoSala) {
    res.status(400).json({ error: 'Falta el código de sala.' });
    return;
  }
  if (!juegoValido(juegoId) || juegoId === JUEGO_GLOBAL) {
    res.status(400).json({ error: 'Juego no válido.' });
    return;
  }

  const ya = await apuestas().findOne({
    codigoSala,
    estado: 'resuelta',
  });
  if (ya) {
    const doc = await usuarios().findOne({ _id: req.usuario._id });
    res.json({
      ok: true,
      yaResuelta: true,
      pot: 0,
      usuario: publico(doc),
    });
    return;
  }

  const retenidas = await apuestas()
    .find({ codigoSala, estado: 'retenida' })
    .toArray();
  if (retenidas.length === 0) {
    const doc = await usuarios().findOne({ _id: req.usuario._id });
    res.json({ ok: true, pot: 0, usuario: publico(doc) });
    return;
  }

  const soyApostador = retenidas.some(
    (a) => String(a.usuarioId) === String(req.usuario._id),
  );
  if (!soyApostador) {
    res.status(403).json({ error: 'No participaste de esta apuesta.' });
    return;
  }

  const pot = retenidas.reduce((s, a) => s + (Number(a.monto) || 0), 0);
  if (pot <= 0) {
    await apuestas().updateMany(
      { codigoSala, estado: 'retenida' },
      { $set: { estado: 'resuelta', resueltaEn: new Date() } },
    );
    const doc = await usuarios().findOne({ _id: req.usuario._id });
    res.json({ ok: true, pot: 0, usuario: publico(doc) });
    return;
  }

  const campoJuego = `puntos.${juegoId}`;
  const campoGlobal = `puntos.${JUEGO_GLOBAL}`;
  const actualizado = await usuarios().findOneAndUpdate(
    { _id: req.usuario._id },
    {
      $inc: {
        monedas: pot,
        [campoJuego]: pot,
        [campoGlobal]: pot,
      },
      $set: { actualizadoEn: new Date() },
    },
    { returnDocument: 'after' },
  );
  const actual =
    actualizado && actualizado.value !== undefined
      ? actualizado.value
      : actualizado;

  await apuestas().updateMany(
    { codigoSala, estado: 'retenida' },
    {
      $set: {
        estado: 'resuelta',
        resueltaEn: new Date(),
        ganadorId: req.usuario._id,
        pot,
      },
    },
  );

  await partidas().insertOne({
    usuarioId: req.usuario._id,
    tipo: 'apuestaOnline',
    codigoSala,
    juegoId,
    monedas: pot,
    puntos: pot,
    fecha: new Date(),
  });

  res.json({
    ok: true,
    pot,
    usuario: publico(actual),
  });
}

// Re-export helper used after circular import pattern — defined in usuarios
export { montoOk, MONTOS_OK };
