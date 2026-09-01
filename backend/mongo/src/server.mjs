import cors from 'cors';
import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import { conectar } from './db.mjs';
import { apiHost, apiPort, nombreDb, uri } from './env.mjs';
import {
  exigirUsuario,
  login,
  pedirRecuperacion,
  ranking,
  reenviar,
  reenviarRecuperacion,
  registrar,
  restablecerClave,
  sumarMonedasVictoriaPc,
  sumarPuntos,
  verificar,
  verificarRecuperacion,
  yo,
  cambiarNombreUsuario,
  calendarioRacha,
  reestablecerRachaUsuario,
  eliminarCuenta,
} from './usuarios.mjs';
import { listarCofres, reclamarCofre } from './cofres.mjs';
import {
  reembolsarApuesta,
  resolverApuesta,
  retenerApuesta,
} from './apuestas.mjs';

const app = express();
app.use(cors());

const salasPort = process.env.SALAS_INTERNAL_PORT;
if (salasPort) {
  const salasTarget = `http://127.0.0.1:${salasPort}`;
  // No montar en app.use('/api/sala', …): Express recorta el prefijo y Spring
  // recibe path "/" → 404. pathFilter conserva /api/sala al reenviar.
  app.use(
    createProxyMiddleware({
      target: salasTarget,
      changeOrigin: true,
      pathFilter: (pathname) =>
        pathname === '/api/sala' || pathname.startsWith('/api/sala/'),
    }),
  );
  console.log(`Proxy /api/sala → ${salasTarget}`);
}

app.use(express.json({ limit: '32kb' }));

app.get('/api/salud', (_req, res) => {
  res.json({
    ok: true,
    db: nombreDb,
    mongo: uri.includes('mongodb+srv') ? 'atlas' : 'local',
    salas: salasPort ? `proxy→127.0.0.1:${salasPort}` : 'off',
  });
});

app.post('/api/usuarios/registro', registrar);
app.post('/api/usuarios/reenviar', reenviar);
app.post('/api/usuarios/verificar', verificar);
app.post('/api/usuarios/login', login);
app.post('/api/usuarios/recuperar', pedirRecuperacion);
app.post('/api/usuarios/recuperar/reenviar', reenviarRecuperacion);
app.post('/api/usuarios/recuperar/verificar', verificarRecuperacion);
app.post('/api/usuarios/recuperar/restablecer', restablecerClave);
app.get('/api/usuarios/yo', exigirUsuario, yo);
app.get('/api/usuarios/racha-calendario', exigirUsuario, calendarioRacha);
app.post(
  '/api/usuarios/reestablecer-racha',
  exigirUsuario,
  reestablecerRachaUsuario,
);
app.post(
  '/api/usuarios/cambiar-nombre',
  exigirUsuario,
  cambiarNombreUsuario,
);
app.post('/api/usuarios/eliminar', exigirUsuario, eliminarCuenta);
app.post('/api/monedas/victoria-pc', exigirUsuario, sumarMonedasVictoriaPc);
app.post('/api/apuestas/retener', exigirUsuario, retenerApuesta);
app.post('/api/apuestas/reembolsar', exigirUsuario, reembolsarApuesta);
app.post('/api/apuestas/resolver', exigirUsuario, resolverApuesta);
app.post('/api/puntos', exigirUsuario, sumarPuntos);
app.get('/api/ranking', ranking);
app.get('/api/cofres', exigirUsuario, listarCofres);
app.post('/api/cofres/reclamar', exigirUsuario, reclamarCofre);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Error interno.' });
});

await conectar();
app.listen(apiPort, apiHost, () => {
  console.log(`API Mongo en http://127.0.0.1:${apiPort}`);
  console.log(`Base: ${nombreDb}  |  ${uri}`);
  console.log('Compass: conectate a mongodb://127.0.0.1:27017 y abrí juegosMesa → usuarios');
});
