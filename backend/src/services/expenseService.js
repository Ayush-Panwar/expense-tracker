const prisma = require('../config/db');

const createExpense = async (userId, data) => {
    const existing = await prisma.expense.findUnique({ where: { id: data.id } });

    if (existing && existing.userId !== userId) {
        throw new Error('Unauthorized');
    }

    // if expense was deleted on another device, don't recreate it
    if (existing && existing.deletedAt) {
        return existing;
    }

    const expense = await prisma.expense.upsert({
        where: { id: data.id },
        update: {
            amount: data.amount,
            category: data.category,
            note: data.note || null,
            date: new Date(data.date),
            imageUrl: data.imageUrl || null,
        },
        create: {
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

const getExpenses = async (userId, { page = 1, limit = 20, category, search } = {}) => {
    const skip = (page - 1) * limit;
    const take = Math.min(limit, 100);

    const where = {
        userId: userId,
        deletedAt: null,
    };

    if (category) {
        where.category = category;
    }

    if (search) {
        where.note = { contains: search, mode: 'insensitive' };
    }

    const [expenses, total] = await Promise.all([
        prisma.expense.findMany({
            where,
            orderBy: { date: 'desc' },
            skip,
            take,
        }),
        prisma.expense.count({ where }),
    ]);

    return {
        expenses,
        total,
        page,
        totalPages: Math.ceil(total / take),
    };
};

const getSummary = async (userId) => {
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - weekStart.getDay() + 1);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const baseWhere = { userId, deletedAt: null };

    const [today, week, month] = await Promise.all([
        prisma.expense.aggregate({
            where: { ...baseWhere, date: { gte: todayStart } },
            _sum: { amount: true },
        }),
        prisma.expense.aggregate({
            where: { ...baseWhere, date: { gte: weekStart } },
            _sum: { amount: true },
        }),
        prisma.expense.aggregate({
            where: { ...baseWhere, date: { gte: monthStart } },
            _sum: { amount: true },
        }),
    ]);

    return {
        today: parseFloat(today._sum.amount || 0),
        week: parseFloat(week._sum.amount || 0),
        month: parseFloat(month._sum.amount || 0),
    };
};

const getChangesSince = async (userId, since) => {
    const where = {
        userId: userId,
        updatedAt: { gt: since },
    };

    const changes = await prisma.expense.findMany({
        where,
        orderBy: { updatedAt: 'asc' },
        take: 500,
    });

    const upserted = changes.filter(e => e.deletedAt === null);
    const deleted = changes.filter(e => e.deletedAt !== null).map(e => e.id);
    const total = await prisma.expense.count({ where });
    const hasMore = total > 500;

    const serverTime = changes.length > 0
        ? changes[changes.length - 1].updatedAt.toISOString()
        : new Date().toISOString();

    return { upserted, deleted, serverTime, hasMore };
};

const deleteExpense = async (userId, expenseId) => {
    const expense = await prisma.expense.findFirst({
        where: { id: expenseId, userId: userId },
    });

    // idempotent — if already deleted or doesn't exist, still succeed
    if (!expense) {
        return null;
    }

    if (expense.deletedAt) {
        return expense;
    }

    await prisma.expense.update({
        where: { id: expenseId },
        data: { deletedAt: new Date() },
    });

    return expense;
};

module.exports = { createExpense, getExpenses, getSummary, getChangesSince, deleteExpense };
