const expenseService = require('../services/expenseService');
const storageService = require('../services/storageService');

const createExpense = async (req, res) => {
    try {
        const { id, amount, category, note, date } = req.body;

        if (!id || !amount || !category || !date) {
            return res.status(422).json({ error: 'Missing required fields' });
        }

        let imageUrl = null;
        if (req.file) {
            imageUrl = await storageService.uploadImage(req.file);
        }

        const expense = await expenseService.createExpense(req.userId, {
            id, amount, category, note, date, imageUrl,
        });

        res.status(201).json(expense);
    } catch (err) {
        res.status(500).json({ error: 'Something went wrong' });
    }
};

const getExpenses = async (req, res) => {
    try {
        const expenses = await expenseService.getExpenses(req.userId);
        res.json({ expenses });
    } catch (err) {
        res.status(500).json({ error: 'Something went wrong' });
    }
};

const deleteExpense = async (req, res) => {
    try {
        await expenseService.deleteExpense(req.userId, req.params.id);
        res.json({ message: 'Expense deleted successfully' });
    } catch (err) {
        if (err.message === 'Expense not found') {
            return res.status(404).json({ error: err.message });
        }
        res.status(500).json({ error: 'Something went wrong' });
    }
};

module.exports = { createExpense, getExpenses, deleteExpense };