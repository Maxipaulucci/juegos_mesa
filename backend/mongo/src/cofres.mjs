import { partidas, usuarios } from './db.mjs';
import { asegurarMonedasIniciales, publico } from './usuarios.mjs';

export const COFRES = {
  madera: { monedas: 10, cooldownMs: 4 * 60 * 60 * 1000 },
  oro: { monedas: 75, cooldownMs: 24 * 60 * 60 * 1000 },
};

function campoReclamado(tipo) {
  return tipo === 'madera' ? 'cofreMaderaReclamadoEn' : 'cofreOroReclamadoEn';
}

export function estadoCofre(doc, tipo) {
  const cfg = COFRES[tipo];
  if (!cfg) return null;
  const campo = campoReclamado(tipo);
  const raw = doc?.[campo];
  const ultimo = raw ? new Date(raw).getTime() : 0;
  const ahora = Date.now();
  const transcurrido = ultimo > 0 ? ahora - ultimo : Number.POSITIVE_INFINITY;
  const listo = !ultimo || transcurrido >= cfg.cooldownMs;
  const restanteMs = listo ? 0 : Math.max(0, cfg.cooldownMs - transcurrido);
  return {
    listo,
    monedas: cfg.monedas,
    cooldownMs: cfg.cooldownMs,
    restanteMs,
  };
}

export function estadosCofres(doc) {
  return {
    madera: estadoCofre(doc, 'madera'),
    oro: estadoCofre(doc, 'oro'),
  };
}

export async function listarCofres(req, res) {
  const doc = await asegurarMonedasIniciales(req.usuario);
  res.json({ cofres: estadosCofres(doc) });
}

export async function reclamarCofre(req, res) {
  const tipo = String(req.body?.tipo || '').trim().toLowerCase();
  const cfg = COFRES[tipo];
  if (!cfg) {
    res.status(400).json({ error: 'Tipo de cofre no válido.' });
    return;
  }

  const doc = await asegurarMonedasIniciales(req.usuario);
  const estado = estadoCofre(doc, tipo);
  if (!estado?.listo) {
    res.status(400).json({
      error: 'Todavía no podés reclamar este cofre.',
      restanteMs: estado?.restanteMs ?? 0,
    });
    return;
  }

  const campo = campoReclamado(tipo);
  const ahora = new Date();
  const actualizado = await usuarios().findOneAndUpdate(
    { _id: req.usuario._id },
    {
      $inc: { monedas: cfg.monedas },
      $set: { [campo]: ahora, actualizadoEn: ahora },
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
    tipo: 'cofre',
    cofre: tipo,
    monedas: cfg.monedas,
    fecha: ahora,
  });

  res.json({
    usuario: publico(actual),
    cofre: tipo,
    monedasSumadas: cfg.monedas,
    cofres: estadosCofres(actual),
  });
}
