import cors from 'cors';
import express from 'express';
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
  sumarPuntos,
  verificar,
  verificarRecuperacion,
  yo,
} from './usuarios.mjs';

const app = express();
app.use(cors());
app.use(express.json({ limit: '32kb' }));

app.get('/api/salud', (_req, res) => {
  res.json({ ok: true, db: nombreDb, mongo: uri });
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
app.post('/api/puntos', exigirUsuario, sumarPuntos);
app.get('/api/ranking', ranking);

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
