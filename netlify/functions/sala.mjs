import { getStore } from '@netlify/blobs'
import { randomBytes } from 'node:crypto'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

/** Letras y dígitos (sin I/O/0/1 para evitar confusiones al dictar). */
const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
const DIGITS = '23456789'
const CHARS = LETTERS + DIGITS
const CODIGO_REGEX = /^[A-Za-z0-9]{6}$/
/** Tras iniciar la partida, el código/sala se elimina a la 1 h. */
const TTL_PARTIDA_MS = 60 * 60 * 1000

function codigoValido(codigo) {
  return CODIGO_REGEX.test(codigo)
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  })
}

/** Código de 6 chars alfanumérico con al menos 1 letra y 1 número. */
function generarCodigo(largo = 6) {
  const bytes = randomBytes(largo)
  const chars = []
  for (let i = 0; i < largo; i++) {
    chars.push(CHARS[bytes[i] % CHARS.length])
  }
  // Garantizar mezcla letra + número.
  const hasLetter = chars.some((c) => LETTERS.includes(c))
  const hasDigit = chars.some((c) => DIGITS.includes(c))
  if (!hasLetter) {
    chars[bytes[0] % largo] = LETTERS[bytes[1] % LETTERS.length]
  }
  if (!hasDigit) {
    const idx = (bytes[0] + 1) % largo
    chars[idx] = DIGITS[bytes[2] % DIGITS.length]
  }
  return chars.join('')
}

async function codigoLibre(store) {
  for (let i = 0; i < 24; i++) {
    const codigo = generarCodigo(6)
    const existe = await store.get(codigo, {
      type: 'json',
      consistency: 'strong',
    })
    if (!existe) return codigo
    // Si existe pero ya expiró, se puede reutilizar.
    if (await salaExpiradaYBorrar(store, codigo, existe)) return codigo
  }
  throw new Error('No se pudo generar un código libre. Reintentá.')
}

function partidaExpirada(sala) {
  if (!sala?.iniciadaEn) return false
  return Date.now() - Number(sala.iniciadaEn) >= TTL_PARTIDA_MS
}

async function salaExpiradaYBorrar(store, codigo, sala) {
  if (!partidaExpirada(sala)) return false
  try {
    await store.delete(codigo)
  } catch (_) {}
  return true
}

/** Lee sala; si la partida lleva >1 h iniciada, la borra y devuelve null. */
async function leerSala(store, codigo) {
  const sala = await store.get(codigo, { type: 'json', consistency: 'strong' })
  if (!sala) return null
  if (await salaExpiradaYBorrar(store, codigo, sala)) return null
  return sala
}

/** Guarda la sala (la expiración se aplica al leer vía iniciadaEn). */
async function guardarSala(store, codigo, sala) {
  await store.setJSON(codigo, sala)
}

function nuevoId(prefix) {
  return `${prefix}-${randomBytes(6).toString('hex')}`
}

/** Orden de fases Tutti Frutti (evita que acelerar ruleta pise un PARAR). */
const TUTI_FASE_ORDEN = {
  countdownRuleta: 0,
  ruleta: 1,
  countdownEscritura: 2,
  escritura: 3,
  countdownRevision: 4,
  revision: 5,
  fin: 6,
}

function tutiFaseRegresa(prev, next) {
  if (!prev || prev.juego !== 'tutiFruti' || next?.juego !== 'tutiFruti') {
    return false
  }
  const prevRonda = Number(prev.ronda) || 1
  const nextRonda = Number(next.ronda) || 1
  if (nextRonda < prevRonda) return true
  if (nextRonda > prevRonda) return false
  const prevOrden = TUTI_FASE_ORDEN[prev.fase] ?? 0
  const nextOrden = TUTI_FASE_ORDEN[next.fase] ?? 0
  return nextOrden < prevOrden
}

/** Evita que un sync de respuestas sin BASTA pise un BASTA ya publicado. */
function tutiBastaPisado(prev, next) {
  if (!prev || prev.juego !== 'tutiFruti' || next?.juego !== 'tutiFruti') {
    return false
  }
  if (prev.bastaTodos !== true || next.bastaTodos === true) return false
  const prevRonda = Number(prev.ronda) || 1
  const nextRonda = Number(next.ronda) || 1
  if (nextRonda !== prevRonda) return false
  return prev.fase === 'escritura' && next.fase === 'escritura'
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
      const sala = await leerSala(store, codigo)
      if (!sala) {
        return json(404, {
          error:
            'No existe una sala con ese código (o expiró tras 1 hora de juego).',
        })
      }
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

      // El código siempre lo genera el servidor (alfanumérico aleatorio).
      const codigo = await codigoLibre(store)

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
      await guardarSala(store, codigo, sala)
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

      const sala = await leerSala(store, codigo)
      if (!sala) {
        return json(404, {
          error:
            'No existe una sala con ese código (o expiró tras 1 hora de juego).',
        })
      }
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
      await guardarSala(store, codigo, sala)
      return json(200, { sala, miId })
    }

    if (action === 'expulsar') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const anfitrionId = body.anfitrionId
      const jugadorId = body.jugadorId
      const sala = await leerSala(store, codigo)
      if (!sala) {
        return json(404, {
          error:
            'No existe una sala con ese código (o expiró tras 1 hora de juego).',
        })
      }
      if (sala.anfitrionId !== anfitrionId) {
        return json(403, { error: 'Solo el anfitrión puede expulsar.' })
      }
      if (jugadorId === sala.anfitrionId) {
        return json(400, { error: 'No podés expulsar al anfitrión.' })
      }
      sala.jugadores = sala.jugadores.filter((j) => j.id !== jugadorId)
      await guardarSala(store, codigo, sala)
      return json(200, { sala })
    }

    if (action === 'iniciar') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const anfitrionId = body.anfitrionId
      const dados = body.dados === 6 ? 6 : 5
      const sala = await leerSala(store, codigo)
      if (!sala) {
        return json(404, {
          error:
            'No existe una sala con ese código (o expiró tras 1 hora de juego).',
        })
      }
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
      } else if (sala.juegoId === 'laPapa') {
        // El anfitrión publica el tablero real al entrar a la partida.
        const opts =
          body.opcionesPapa && typeof body.opcionesPapa === 'object'
            ? body.opcionesPapa
            : {}
        const modoFantasma = opts.modoFantasma === true
        const conVidas = !modoFantasma && opts.conVidas === true
        let cantidad = Number(opts.cantidadNumeros)
        if (!Number.isFinite(cantidad)) cantidad = 30
        cantidad = Math.floor(cantidad)
        if (modoFantasma) cantidad = 50
        if (cantidad < 2) cantidad = 2
        if (cantidad > 50) cantidad = 50
        const vidas = conVidas ? nombres.map(() => 3) : []
        const aleatorios = modoFantasma || opts.numerosAleatorios !== false
        sala.gameState = {
          version: 1,
          juego: 'laPapa',
          nombres,
          casillas: null,
          maxNumero: cantidad,
          indiceTurno: 0,
          siguienteConectar: 1,
          siguienteAColocar: 1,
          fase: aleatorios ? 'jugando' : 'colocando',
          mensajeFin: null,
          ganador: null,
          conVidas,
          modoFantasma,
          vidas,
          trazos: [],
          trazoFallido: [],
          opciones: {
            conVidas: !!opts.conVidas,
            numerosAleatorios: opts.numerosAleatorios !== false,
            cantidadNumeros: cantidad,
            modoFantasma,
            mostrarCuadricula: opts.mostrarCuadricula !== false,
          },
          mostrarVictoria: false,
          pendienteTablero: true,
        }
      } else if (sala.juegoId === 'escobaDel15') {
        // El anfitrión publica el mazo repartido al entrar a la partida.
        sala.gameState = {
          version: 1,
          juego: 'escobaDel15',
          pendienteMazo: true,
          objetivo: 15,
          indiceTurno: 0,
          fase: 'jugando',
          ultimaCapturaIdx: null,
          mensajeFin: null,
          ganador: null,
          reiniciarCombosEnProximaJugada: false,
          mazo: [],
          mesa: [],
          jugadores: nombres.map((n) => ({
            nombre: n,
            mano: [],
            capturadas: [],
            combos: [],
            escobasRonda: 0,
            puntos: 0,
          })),
          ultimoResultado: null,
          ultimaJugada: null,
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
      await guardarSala(store, codigo, sala)
      return json(200, { sala })
    }

    if (action === 'actualizarLobby') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const anfitrionId = body.anfitrionId
      const sala = await leerSala(store, codigo)
      if (!sala) {
        return json(404, {
          error:
            'No existe una sala con ese código (o expiró tras 1 hora de juego).',
        })
      }
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
      await guardarSala(store, codigo, sala)
      return json(200, { sala })
    }

    if (action === 'actualizarJuego') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const gameState = body.gameState
      if (!codigo) return json(400, { error: 'Falta el código.' })
      if (!gameState || typeof gameState !== 'object') {
        return json(400, { error: 'Falta el estado de juego.' })
      }
      const sala = await leerSala(store, codigo)
      if (!sala) {
        return json(404, {
          error:
            'No existe una sala con ese código (o expiró tras 1 hora de juego).',
        })
      }
      if (sala.estado !== 'jugando') {
        return json(409, { error: 'La partida no está en curso.' })
      }
      const actual = sala.gameState?.version || 0
      const nueva = gameState.version || 0
      if (nueva <= actual) {
        return json(200, { sala, ignored: true })
      }
      // Tutti Frutti: no aceptar ruleta/acelerar si ya hubo PARAR (misma ronda).
      if (tutiFaseRegresa(sala.gameState, gameState)) {
        return json(200, { sala, ignored: true })
      }
      if (tutiBastaPisado(sala.gameState, gameState)) {
        return json(200, { sala, ignored: true })
      }
      sala.gameState = gameState
      if (gameState.mostrarVictoria === true) {
        sala.estado = 'terminada'
      }
      await guardarSala(store, codigo, sala)
      return json(200, { sala })
    }

    if (action === 'cerrar') {
      const codigo = (body.codigo || '').trim().toUpperCase()
      const anfitrionId = body.anfitrionId
      const sala = await leerSala(store, codigo)
      if (!sala) {
        return json(404, {
          error:
            'No existe una sala con ese código (o expiró tras 1 hora de juego).',
        })
      }
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
