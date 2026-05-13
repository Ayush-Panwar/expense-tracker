const validateSignup = (req, res, next) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(422).json({ error: 'Email and password are required' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        return res.status(422).json({ error: 'Invalid email format' });
    }

    if (password.length < 6) {
        return res.status(422).json({ error: 'Password must be at least 6 characters' });
    }

    next();
};

const validateLogin = (req, res, next) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(422).json({ error: 'Email and password are required' });
    }

    next();
};

const validateExpense = (req, res, next) => {
    const { id, amount, category, date } = req.body;

    if (!id || !amount || !category || !date) {
        return res.status(422).json({ error: 'Missing required fields: id, amount, category, date' });
    }

    const validCategories = ['Food', 'Travel', 'Utilities', 'Shopping', 'Health', 'Other'];
    if (!validCategories.includes(category)) {
        return res.status(422).json({
            error: `Invalid category. Must be one of: ${validCategories.join(', ')}`
        });
    }

    const parsedAmount = parseFloat(amount);
    if (isNaN(parsedAmount) || parsedAmount <= 0 || parsedAmount > 99999999.99) {
        return res.status(422).json({ error: 'Amount must be a positive number' });
    }

    next();
};

module.exports = { validateSignup, validateLogin, validateExpense };
