import { getStore } from '@netlify/blobs'
import { randomBytes } from 'node:crypto'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

const CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const CODIGO_REGEX = /^[A-Za-z0-9]{6}$/

function codigoValido(codigo) {
  return CODIGO_REGEX.test(codigo)
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  })
}

function generarCodigo(largo = 6) {
  const bytes = randomBytes(largo)
  let out = ''
  for (let i = 0; i < largo; i++) {
    out += CHARS[bytes[i] % CHARS.length]
  }
  return out
}

function nuevoId(prefix) {
  return `${prefix}-${randomBytes(6).toString('hex')}`
}

export default async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('', { status: 204, headers: CORS })
  }

  const store = getStore('salas')
  const url = new URL(req.url)

  try {
    if (req.method === 'GET') {
      const codigo = (url.searchParams.get('codigo') || '').trim().toUpperCase()
      if (!codigo) return json(400, { error: 'Falta el código.' })
      const sala = await store.get(codigo, { type: 'json', consistency: 'strong' })
      if (!sala) return json(404, { error: 'No existe una sala con ese código.' })
      return json(200, { sala })
    }

    if (req.method !== 'POST') {
      return json(405, { error: 'Método no permitido.' })
    }

    const body = await req.json()
    const action = body?.action

    if (action === 'crear') {
      const juegoId = (body.juegoId || '').trim()
      const nombre = (body.nombre || '').trim()
      if (!juegoId) return json(400, { error: 'Falta el juego.' })
      if (!nombre) return json(400, { error: 'Escribí tu nombre.' })

      let codigo = (body.codigo || '').trim().toUpperCase()
      if (!codigo) {
        return json(400, { error: 'El código debe tener exactamente 6 caracteres.' })
      }
      if (!codigoValido(codigo)) {
        return json(400, {
          error: 'El código debe tener exactamente 6 caracteres y solo letras o números.',
        })
      }
      const existe = await store.get(codigo, {
        type: 'json',
        consistency: 'strong',
      })
      // Reutilizar código si la sala anterior ya no está en lobby.
      if (existe) {
        if (existe.estado === 'lobby') {
          return json(409, { error: 'Ese código ya está en uso. Probá otro.' })
        }
        await store.delete(codigo)
      }

      const anfitrionId = nuevoId('host')
      const sala = {
        codigo,
        juegoId,
        anfitrionId,
        jugadores: [
          { id: anfitrionId, nombre, rol: 'anfitrion' },
        ],
        estado: 'lobby',
        dados: 5,
        creadaEn: Date.now(),
        lobbyCategorias:
          juegoId === 'tutiFruti' ? ['Nombre', 'Animal', 'Color'] : [],
        lobbyMaxRondas: juegoId === 'tutiFruti' ? 5 : null,
      }
      await store.setJSON(codigo, sala)
      return json(200, { sala, miId: anfitrionId })
    }

    if (action === 'unirse') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const nombre = (body.nombre || '').trim()
      const juegoId = (body.juegoId || '').trim()
      if (!codigo) return json(400, { error: 'Ingresá el código de la sala.' })
      if (!codigoValido(codigo)) {
        return json(400, {
          error: 'El código debe tener exactamente 6 caracteres y solo letras o números.',
        })
      }
      if (!nombre) return json(400, { error: 'Escribí tu nombre.' })

      const sala = await store.get(codigo, { type: 'json', consistency: 'strong' })
      if (!sala) return json(404, { error: 'No existe una sala con ese código.' })
      if (sala.estado !== 'lobby') {
        return json(409, { error: 'La partida ya empezó.' })
      }
      if (juegoId && sala.juegoId !== juegoId) {
        return json(409, { error: 'Esa sala es de otro juego.' })
      }
      if (
        sala.jugadores.some(
          (j) => j.nombre.toLowerCase() === nombre.toLowerCase(),
        )
      ) {
        return json(409, { error: 'Ese nombre ya está en la sala.' })
      }
      if (sala.jugadores.length >= 4) {
        return json(409, { error: 'La sala está llena (máx. 4).' })
      }

      const miId = nuevoId('p')
      sala.jugadores.push({ id: miId, nombre, rol: 'invitado' })
      await store.setJSON(codigo, sala)
      return json(200, { sala, miId })
    }

    if (action === 'expulsar') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const anfitrionId = body.anfitrionId
      const jugadorId = body.jugadorId
      const sala = await store.get(codigo, { type: 'json', consistency: 'strong' })
      if (!sala) return json(404, { error: 'No existe una sala con ese código.' })
      if (sala.anfitrionId !== anfitrionId) {
        return json(403, { error: 'Solo el anfitrión puede expulsar.' })
      }
      if (jugadorId === sala.anfitrionId) {
        return json(400, { error: 'No podés expulsar al anfitrión.' })
      }
      sala.jugadores = sala.jugadores.filter((j) => j.id !== jugadorId)
      await store.setJSON(codigo, sala)
      return json(200, { sala })
    }

    if (action === 'iniciar') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const anfitrionId = body.anfitrionId
      const dados = body.dados === 6 ? 6 : 5
      const sala = await store.get(codigo, { type: 'json', consistency: 'strong' })
      if (!sala) return json(404, { error: 'No existe una sala con ese código.' })
      if (sala.anfitrionId !== anfitrionId) {
        return json(403, { error: 'Solo el anfitrión puede iniciar.' })
      }
      if (sala.jugadores.length < 2) {
        return json(400, { error: 'Hacen falta al menos 2 jugadores.' })
      }
      sala.estado = 'jugando'
      sala.dados = dados
      sala.iniciadaEn = Date.now()
      // Estado inicial de partida para sync online (anfitrión empieza).
      const nombres = sala.jugadores.map((j) => j.nombre)
      if (sala.juegoId === 'tutiFruti') {
        const rawCats = Array.isArray(body.categorias) ? body.categorias : []
        const cats = rawCats
          .map((c) => String(c || '').trim())
          .filter((c) => c.length > 0)
        if (cats.length < 3 || cats.length > 6) {
          return json(400, { error: 'Tutti Frutti: entre 3 y 6 categorías.' })
        }
        for (const c of cats) {
          if (c.length > 25) {
            return json(400, {
              error: 'Cada categoría puede tener hasta 25 caracteres.',
            })
          }
        }
        const now = Date.now()
        let maxRondas = Number(body.maxRondas)
        if (!Number.isFinite(maxRondas)) maxRondas = 5
        maxRondas = Math.floor(maxRondas)
        if (maxRondas < 1 || maxRondas > 26) {
          return json(400, {
            error: 'Tutti Frutti: rondas entre 1 y 26 (abecedario).',
          })
        }
        const respuestas = {}
        const listos = {}
        const puntajes = {}
        const totales = {}
        for (const n of nombres) {
          respuestas[n] = cats.map(() => '')
          listos[n] = false
          puntajes[n] = cats.map(() => null)
          totales[n] = 0
        }
        sala.gameState = {
          version: 1,
          juego: 'tutiFruti',
          categorias: cats,
          nombres,
          fase: 'countdownRuleta',
          indiceSpinner: 0,
          ronda: 1,
          maxRondas,
          letra: null,
          letrasUsadas: [],
          ruletaInicioMs: null,
          ruletaVelocidad: 8,
          faseInicioMs: now,
          respuestas,
          listos,
          bastaTodos: false,
          bastaInicioMs: null,
          bastaPor: null,
          categoriaRevision: 0,
          puntajes,
          totales,
          mostrarVictoria: false,
        }
      } else if (sala.juegoId === 'generala') {
        const cats = [
          '1', '2', '3', '4', '5', '6',
          'ESCALERA', 'FULL', 'POKER', 'GENERALA', 'GENERALA DOBLE',
        ]
        sala.gameState = {
          version: 1,
          juego: 'generala',
          indiceTurno: 0,
          ganador: null,
          jugadores: nombres.map((n) => ({
            nombre: n,
            rendido: false,
            casillas: Object.fromEntries(cats.map((c) => [c, null])),
          })),
          turno: {
            dados: [],
            guardados: [false, false, false, false, false],
            tiradasHechas: 0,
          },
          modoAnotar: false,
          mostrarVictoria: false,
        }
      } else {
        sala.gameState = {
          version: 1,
          juego: 'diezMil',
          modo: dados,
          indiceTurno: 0,
          ganador: null,
          jugadores: nombres.map((n) => ({
            nombre: n,
            puntos: 0,
            abierto: false,
            rendido: false,
          })),
          turno: {
            dadosEnMano: dados,
            puntosTurno: 0,
            tiradaNro: 0,
            abiertoEstaRonda: false,
          },
          mostrarVictoria: false,
          mensaje: null,
          ultimaTiradaDados: null,
          ultimoResumen: null,
        }
      }
      await store.setJSON(codigo, sala)
      return json(200, { sala })
    }

    if (action === 'actualizarLobby') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const anfitrionId = body.anfitrionId
      const sala = await store.get(codigo, { type: 'json', consistency: 'strong' })
      if (!sala) return json(404, { error: 'No existe una sala con ese código.' })
      if (sala.anfitrionId !== anfitrionId) {
        return json(403, { error: 'Solo el anfitrión puede editar la sala.' })
      }
      if (sala.estado !== 'lobby') {
        return json(409, { error: 'La partida ya empezó.' })
      }
      const rawCats = Array.isArray(body.categorias) ? body.categorias : []
      const cats = rawCats
        .map((c) => String(c || '').trim())
        .filter((c) => c.length > 0)
        .slice(0, 6)
        .map((c) => (c.length > 25 ? c.slice(0, 25) : c))
      let maxRondas = Number(body.maxRondas)
      if (!Number.isFinite(maxRondas)) maxRondas = 5
      maxRondas = Math.floor(maxRondas)
      if (maxRondas < 1) maxRondas = 1
      if (maxRondas > 26) maxRondas = 26
      sala.lobbyCategorias = cats
      sala.lobbyMaxRondas = maxRondas
      await store.setJSON(codigo, sala)
      return json(200, { sala })
    }

    if (action === 'actualizarJuego') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const gameState = body.gameState
      if (!codigo) return json(400, { error: 'Falta el código.' })
      if (!gameState || typeof gameState !== 'object') {
        return json(400, { error: 'Falta el estado de juego.' })
      }
      const sala = await store.get(codigo, { type: 'json', consistency: 'strong' })
      if (!sala) return json(404, { error: 'No existe una sala con ese código.' })
      if (sala.estado !== 'jugando') {
        return json(409, { error: 'La partida no está en curso.' })
      }
      const actual = sala.gameState?.version || 0
      const nueva = gameState.version || 0
      if (nueva <= actual) {
        return json(200, { sala, ignored: true })
      }
      sala.gameState = gameState
      if (gameState.mostrarVictoria === true) {
        sala.estado = 'terminada'
      }
      await store.setJSON(codigo, sala)
      return json(200, { sala })
    }

    if (action === 'cerrar') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const anfitrionId = body.anfitrionId
      const sala = await store.get(codigo, { type: 'json', consistency: 'strong' })
      if (!sala) return json(404, { error: 'No existe una sala con ese código.' })
      if (sala.anfitrionId !== anfitrionId) {
        return json(403, { error: 'Solo el anfitrión puede cerrar la sala.' })
      }
      await store.delete(codigo)
      return json(200, { ok: true })
    }

    return json(400, { error: 'Acción desconocida.' })
  } catch (e) {
    return json(500, { error: e?.message || 'Error del servidor.' })
  }
}
