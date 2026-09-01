import { partidas, usuarios } from './db.mjs';

export const RACHA = {
  diaria: 5,
  semana: 100,
  mes: 1000,
  diasSemana: 7,
  diasMes: 30,
};

const TZ = 'America/Argentina/Buenos_Aires';

export function hoyLocal() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: TZ }).format(new Date());
}

function parseDia(iso) {
  const [y, m, d] = String(iso).split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d));
}

function esDiaConsecutivo(ultimoDia, hoy) {
  if (!ultimoDia || !hoy) return false;
  const a = parseDia(ultimoDia);
  const b = parseDia(hoy);
  const diff = Math.round((b - a) / (24 * 60 * 60 * 1000));
  return diff === 1;
}

export function estadoRacha(doc) {
  const info = rachaPublica(doc);
  return {
    aplicada: false,
    monedasSumadas: 0,
    diasRacha: info.diasActual,
    diasMaxima: info.diasMaxima,
    bonusSemana: false,
    bonusMes: false,
    reinicioCiclo: false,
  };
}

export function rachaPublica(doc) {
  const hoy = hoyLocal();
  const ultimo = doc?.loginRachaUltimoDia || null;
  const dias = Number(doc?.loginRachaDias) || 0;
  const maxima = Number(doc?.loginRachaMaxima) || 0;

  let actual = 0;
  if (ultimo === hoy) {
    actual = dias;
  } else if (ultimo && esDiaConsecutivo(ultimo, hoy)) {
    actual = dias;
  }

  return {
    diasActual: actual,
    diasMaxima: Math.max(maxima, actual),
  };
}

/**
 * +5 por día consecutivo; +100 al día 7; +1000 al día 30; luego reinicia el ciclo.
 */
export async function procesarRachaDiaria(doc) {
  const hoy = hoyLocal();
  const ultimo = doc?.loginRachaUltimoDia || null;
  const diasPrevios = Number(doc?.loginRachaDias) || 0;

  if (ultimo === hoy) {
    return estadoRacha(doc);
  }

  let dias = 1;
  if (ultimo && esDiaConsecutivo(ultimo, hoy)) {
    dias = diasPrevios >= RACHA.diasMes ? 1 : diasPrevios + 1;
  }

  let monedas = RACHA.diaria;
  let bonusSemana = false;
  let bonusMes = false;
  let reinicioCiclo = false;

  if (dias === RACHA.diasSemana) {
    monedas += RACHA.semana;
    bonusSemana = true;
  }
  if (dias === RACHA.diasMes) {
    monedas += RACHA.mes;
    bonusMes = true;
    reinicioCiclo = true;
  }

  const ahora = new Date();
  const maxima = Math.max(Number(doc?.loginRachaMaxima) || 0, dias);
  const actualizado = await usuarios().findOneAndUpdate(
    { _id: doc._id },
    {
      $inc: { monedas },
      $set: {
        loginRachaDias: dias,
        loginRachaUltimoDia: hoy,
        loginRachaMaxima: maxima,
        actualizadoEn: ahora,
      },
    },
    { returnDocument: 'after' },
  );
  const actual =
    actualizado && actualizado.value !== undefined
      ? actualizado.value
      : actualizado;

  await partidas().insertOne({
    usuarioId: doc._id,
    tipo: 'rachaDiaria',
    monedas,
    diasRacha: dias,
    bonusSemana,
    bonusMes,
    fecha: ahora,
  });

  return {
    aplicada: true,
    monedasSumadas: monedas,
    diasRacha: dias,
    bonusSemana,
    bonusMes,
    reinicioCiclo,
    usuario: actual,
  };
}

export async function aplicarRachaSiCorresponde(doc) {
  const resultado = await procesarRachaDiaria(doc);
  const usuario = resultado.usuario || doc;
  const info = rachaPublica(usuario);
  return {
    usuario,
    racha: {
      aplicada: resultado.aplicada,
      monedasSumadas: resultado.monedasSumadas,
      diasRacha: info.diasActual,
      diasMaxima: info.diasMaxima,
      bonusSemana: resultado.bonusSemana,
      bonusMes: resultado.bonusMes,
      reinicioCiclo: resultado.reinicioCiclo,
      objetivoSemana: RACHA.diasSemana,
      objetivoMes: RACHA.diasMes,
    },
  };
}

/** Días del mes (1–31) en que el usuario inició sesión para la racha. */
export async function diasLoginEnMes(usuarioId, anio, mes) {
  const startUtc = new Date(Date.UTC(anio, mes - 1, 1, 3, 0, 0));
  const endUtc = new Date(Date.UTC(anio, mes, 1, 3, 0, 0));

  const docs = await partidas()
    .find({
      usuarioId,
      tipo: 'rachaDiaria',
      fecha: { $gte: startUtc, $lt: endUtc },
    })
    .toArray();

  const dias = new Set();
  for (const doc of docs) {
    if (!doc?.fecha) continue;
    const iso = new Intl.DateTimeFormat('en-CA', { timeZone: TZ }).format(
      new Date(doc.fecha),
    );
    const [y, m, d] = iso.split('-').map(Number);
    if (y === anio && m === mes && d >= 1 && d <= 31) dias.add(d);
  }

  return [...dias].sort((a, b) => a - b);
}
