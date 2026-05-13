const express = require('express');
const cors = require('cors');
require('dotenv').config();

// log env status on startup
console.log('ENV CHECK:', {
  hasDbUrl: !!process.env.DATABASE_URL,
  hasJwtSecret: !!process.env.JWT_SECRET,
  hasSupabaseUrl: !!process.env.SUPABASE_URL,
  hasSupabaseKey: !!process.env.SUPABASE_SERVICE_KEY,
  port: process.env.PORT,
});

const authRoutes = require('./src/routes/authRoutes');
const expenseRoutes = require('./src/routes/expenseRoutes');

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/expenses', expenseRoutes);

app.get('/', (req, res) => {
    res.json({ message: 'Expense Tracker API running' });
});

const errorHandler = require('./src/middleware/errorHandler');
app.use(errorHandler);

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});