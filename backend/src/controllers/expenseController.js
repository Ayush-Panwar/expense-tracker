const expenseService = require('../services/expenseService');
const storageService = require('../services/storageService');

const createExpense = async (req, res) => {
    try {
        const { id, amount, category, note, date } = req.body;

        let imageUrl = null;
        if (req.file) {
            imageUrl = await storageService.uploadImage(req.file);
        }

        const expense = await expenseService.createExpense(req.userId, {
            id, amount, category, note, date, imageUrl,
        });

        res.status(201).json(expense);
    } catch (err) {
        console.error('createExpense error:', err.message);
        if (err.message === 'Unauthorized') {
            return res.status(403).json({ error: 'Not authorized' });
        }
        res.status(500).json({ error: 'Something went wrong' });
    }
};

const getExpenses = async (req, res) => {
    try {
        const { page, limit, category, search } = req.query;

        const result = await expenseService.getExpenses(req.userId, {
            page: parseInt(page) || 1,
            limit: parseInt(limit) || 20,
            category: category || undefined,
            search: search || undefined,
        });

        res.json(result);
    } catch (err) {
        console.error('getExpenses error:', err.message);
        res.status(500).json({ error: 'Something went wrong' });
    }
};

const getSummary = async (req, res) => {
    try {
        const summary = await expenseService.getSummary(req.userId);
        res.json(summary);
    } catch (err) {
        console.error('getSummary error:', err.message);
        res.status(500).json({ error: 'Something went wrong' });
    }
};

const getChangesSince = async (req, res) => {
    try {
        const { since } = req.query;
        const sinceDate = since ? new Date(since) : new Date(0);
        const result = await expenseService.getChangesSince(req.userId, sinceDate);
        res.json(result);
    } catch (err) {
        console.error('getChangesSince error:', err.message);
        res.status(500).json({ error: 'Something went wrong' });
    }
};

const deleteExpense = async (req, res) => {
    try {
        await expenseService.deleteExpense(req.userId, req.params.id);
        res.json({ message: 'Expense deleted successfully' });
    } catch (err) {
        console.error('deleteExpense error:', err.message);
        res.status(500).json({ error: 'Something went wrong' });
    }
};

module.exports = { createExpense, getExpenses, getSummary, getChangesSince, deleteExpense };
