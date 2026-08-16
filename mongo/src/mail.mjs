import nodemailer from 'nodemailer';
import {
  mailFrom,
  smtpHost,
  smtpPass,
  smtpPort,
  smtpUser,
} from './env.mjs';

const NOMBRE_APP = 'Juegos de mesa Argentos';

export function mailConfigurado() {
  return Boolean(smtpHost && smtpUser && smtpPass);
}

function transporter() {
  return nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpPort === 465,
    auth: { user: smtpUser, pass: smtpPass },
  });
}

function textoCodigo(codigo) {
  return (
    `${NOMBRE_APP}\n\n` +
    `Tu código de verificación es: ${codigo}\n` +
    `Este código expira en 15 minutos.`
  );
}

/** Mismo texto que Maxturnos, con el nombre de esta app arriba. */
export async function enviarCodigoRegistro({ email, codigo }) {
  const texto = textoCodigo(codigo);

  if (!mailConfigurado()) {
    console.warn(`[mail] SMTP no configurado. Para ${email}:\n${texto}`);
    return { simulado: true };
  }

  await transporter().sendMail({
    from: mailFrom,
    to: email,
    subject: `Código de Verificación - ${NOMBRE_APP}`,
    text: texto,
  });
  return { simulado: false };
}
