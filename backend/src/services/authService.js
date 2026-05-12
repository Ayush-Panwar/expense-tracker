const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const prisma = require('../config/db');

const signup = async (email, password, name) => {
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
        throw new Error('Email already exists');
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
        data: { email, password: hashedPassword, name },
    });

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
        expiresIn: '7d',
    });

    return { token, user: { id: user.id, email: user.email, name: user.name } };
};

const login = async (email, password) => {
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
        throw new Error('Invalid credentials');
    }

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) {
        throw new Error('Invalid credentials');
    }

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
        expiresIn: '7d',
    });

    return { token, user: { id: user.id, email: user.email, name: user.name } };
};

module.exports = { signup, login };