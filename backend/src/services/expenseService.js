const prisma = require('../config/db');

const createExpense = async (userId, data) => {
    const expense = await prisma.expense.create({
        data: {
            id: data.id,
            amount: data.amount,
            category: data.category,
            note: data.note || null,
            date: new Date(data.date),
            imageUrl: data.imageUrl || null,
            userId: userId,
        },
    });
    return expense;
};

const getExpenses = async (userId) => {
    const expenses = await prisma.expense.findMany({
        where: {
            userId: userId,
            deletedAt: null,
        },
        orderBy: { date: 'desc' },
    });
    return expenses;
};

const deleteExpense = async (userId, expenseId) => {
    const expense = await prisma.expense.findFirst({
        where: { id: expenseId, userId: userId },
    });

    if (!expense) {
        throw new Error('Expense not found');
    }

    await prisma.expense.update({
        where: { id: expenseId },
        data: { deletedAt: new Date() },
    });

    return expense;
};

module.exports = { createExpense, getExpenses, deleteExpense };