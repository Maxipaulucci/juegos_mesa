import { conectar, cerrar, nombreDb, partidas, recuperacionesPendientes, registrosPendientes, uri, usuarios } from '../src/db.mjs';
import { JUEGO_GLOBAL, JUEGOS } from '../src/juegos.mjs';

await conectar();

await usuarios().createIndex({ email: 1 }, { unique: true, name: 'email_unico' });
await usuarios().createIndex(
  { nombreUsuarioNorm: 1 },
  { unique: true, name: 'usuario_unico' },
);
await usuarios().createIndex(
  { [`puntos.${JUEGO_GLOBAL}`]: -1 },
  { name: 'ranking_global' },
);
for (const id of JUEGOS) {
  await usuarios().createIndex({ [`puntos.${id}`]: -1 }, { name: `ranking_${id}` });
}
await partidas().createIndex({ usuarioId: 1, fecha: -1 }, { name: 'partidas_usuario' });
await partidas().createIndex({ juegoId: 1, fecha: -1 }, { name: 'partidas_juego' });

await registrosPendientes().createIndex(
  { expiraEn: 1 },
  { expireAfterSeconds: 0, name: 'ttl_codigo_15min' },
);
await registrosPendientes().createIndex({ email: 1 }, { name: 'pendiente_email' });
await registrosPendientes().createIndex(
  { nombreUsuarioNorm: 1 },
  { name: 'pendiente_usuario' },
);

await recuperacionesPendientes().createIndex(
  { expiraEn: 1 },
  { expireAfterSeconds: 0, name: 'ttl_recupero_15min' },
);
await recuperacionesPendientes().createIndex(
  { email: 1 },
  { name: 'recupero_email' },
);

console.log(`Listo. Base "${nombreDb}" en ${uri}`);
console.log('Colecciones: usuarios, partidas, registrosPendientes, recuperacionesPendientes (TTL 15 min)');
console.log('En Compass: mongodb://127.0.0.1:27017 → juegosMesa → usuarios');

await cerrar();
