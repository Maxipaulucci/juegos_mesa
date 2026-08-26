import { MongoClient } from 'mongodb';
import { nombreDb, uri } from './env.mjs';

let cliente;
let db;

export { nombreDb, uri };

export async function conectar() {
  if (db) return db;
  cliente = new MongoClient(uri);
  await cliente.connect();
  db = cliente.db(nombreDb);
  return db;
}

export function base() {
  if (!db) throw new Error('Mongo no está conectado. Corré scripts/init o npm start.');
  return db;
}

/** Colección que ya creaste en Compass. */
export function usuarios() {
  return base().collection('usuarios');
}

export function partidas() {
  return base().collection('partidas');
}

/** Pedidos de registro con código. Se borran solos a los 15 min. */
export function registrosPendientes() {
  return base().collection('registrosPendientes');
}

/** Pedidos de recuperación de contraseña. Se borran solos a los 15 min. */
export function recuperacionesPendientes() {
  return base().collection('recuperacionesPendientes');
}

/** Apuestas de monedas en salas online (retenidas hasta resolver/reembolsar). */
export function apuestas() {
  return base().collection('apuestas');
}

export async function cerrar() {
  if (cliente) await cliente.close();
  cliente = undefined;
  db = undefined;
}
