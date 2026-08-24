import { Resend } from 'resend';
import { mailFrom, resendApiKey } from './env.mjs';

const NOMBRE_APP = 'Juegos de mesa Argentos';

export function mailConfigurado() {
  return Boolean(resendApiKey);
}

function cliente() {
  return new Resend(resendApiKey);
}

function textoCodigo(codigo) {
  return (
    `${NOMBRE_APP}\n\n` +
    `Tu código de verificación es: ${codigo}\n` +
    `Este código expira en 15 minutos.`
  );
}

/** Envía el código de 6 dígitos por Resend (sirve en Render free). */
export async function enviarCodigoRegistro({ email, codigo }) {
  const texto = textoCodigo(codigo);

  if (!mailConfigurado()) {
    console.warn(`[mail] RESEND_API_KEY no configurada. Para ${email}:\n${texto}`);
    return { simulado: true };
  }

  const { error } = await cliente().emails.send({
    from: mailFrom,
    to: email,
    subject: `Código de Verificación - ${NOMBRE_APP}`,
    text: texto,
  });

  if (error) {
    throw new Error(error.message || 'No se pudo enviar el mail con Resend.');
  }

  return { simulado: false };
}
