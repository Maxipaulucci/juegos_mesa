import nodemailer from 'nodemailer';
import {
  mailFrom,
  smtpHost,
  smtpPass,
  smtpPort,
  smtpUser,
} from './env.mjs';

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

/** Mismo texto que Maxturnos, con el nombre de esta app. */
export async function enviarCodigoRegistro({ email, codigo }) {
  const texto =
    `Tu código de verificación es: ${codigo}\n` +
    `Este código expira en 15 minutos.`;

  if (!mailConfigurado()) {
    console.warn(`[mail] SMTP no configurado. Para ${email}:\n${texto}`);
    return { simulado: true };
  }

  await transporter().sendMail({
    from: mailFrom,
    to: email,
    subject: 'Código de Verificación - Juegos de mesa Argentos',
    text: texto,
  });
  return { simulado: false };
}
