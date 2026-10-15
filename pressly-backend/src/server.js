import 'dotenv/config';
import { createApp, pool } from './app.js';
const port = Number(process.env.PORT || 3000);
try {
  await pool.query('SELECT 1');
  const app = createApp();
  app.listen(port, () => console.log(`Pressly backend listening on http://localhost:${port}`));
} catch (e) { console.error('Database connection failed. Check .env and MySQL setup.'); process.exitCode = 1; await pool.end(); }
