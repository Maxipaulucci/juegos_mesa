import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/cofre_estado.dart';
import 'package:app_juegos_mesa/shared/formato/numero_formato.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel con las formas de sumar monedas en la app.
Future<void> mostrarCartelComoGanarMonedas(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _CartelComoGanarMonedas(),
  );
}

class _CartelComoGanarMonedas extends StatelessWidget {
  const _CartelComoGanarMonedas();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: AppColors.acento,
            size: 26,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '¿Cómo sumar monedas?',
              style: TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PasoMonedas(
              numero: 1,
              icono: Icons.login_rounded,
              titulo: 'Iniciá sesión',
              descripcion:
                  'Registrate e iniciá sesión. Al verificar tu cuenta '
                  'recibís 100 monedas de bienvenida.',
            ),
            const SizedBox(height: 12),
            const _PasoMonedas(
              numero: 2,
              icono: Icons.smart_toy_outlined,
              titulo: 'Ganale a la PC',
              descripcion:
                  'En cualquier juego contra la computadora, si ganás '
                  'la partida sumás +3 monedas.',
            ),
            const SizedBox(height: 12),
            _PasoMonedas(
              numero: 3,
              icono: Icons.inventory_2_outlined,
              titulo: 'Cofres de monedas',
              descripcion:
                  'Reclamá los cofres de la esquina inferior izquierda: '
                  'cofre de madera +${formatoNumero(CofresEstado.maderaMonedas)} monedas '
                  'cada 4 horas y cofre de oro +${formatoNumero(CofresEstado.oroMonedas)} '
                  'monedas por día.',
            ),
            const SizedBox(height: 12),
            const _PasoMonedas(
              numero: 4,
              icono: Icons.local_fire_department_rounded,
              iconoColor: Color(0xFFFF7043),
              titulo: 'Racha de días',
              descripcion:
                  'Entrá cada día con tu cuenta: +5 monedas diarias, '
                  '+100 al completar 7 días seguidos y +1.000 al llegar a '
                  '30 días. Luego el ciclo se reinicia.',
            ),
            const SizedBox(height: 12),
            const _PasoMonedas(
              numero: 5,
              icono: Icons.shopping_cart_rounded,
              iconoColor: AppColors.acento,
              titulo: 'Compras en la app',
              descripcion:
                  'En la sección Tienda podés comprar paquetes de monedas: '
                  '1.000 (US\$ 0.99), 7.500 (US\$ 4.99), 50.000 (US\$ 24.99) '
                  'y el MEGA PACK de 250.000 (US\$ 99.99).',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Entendido',
            style: TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PasoMonedas extends StatelessWidget {
  const _PasoMonedas({
    required this.numero,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    this.iconoColor,
  });

  final int numero;
  final IconData icono;
  final String titulo;
  final String descripcion;
  final Color? iconoColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.fondoSuave.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cartaBorde.withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.acento.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            icono,
            color: iconoColor ?? AppColors.azul,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: TextStyle(
                    color: AppColors.textoSuave.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
