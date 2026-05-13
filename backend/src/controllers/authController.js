const authService = require('../services/authService');

const signup = async (req, res) => {
    try {
        const { email, password, name } = req.body;
        const result = await authService.signup(email, password, name);
        res.status(201).json(result);
    } catch (err) {
        if (err.message === 'Email already exists') {
            return res.status(422).json({ error: err.message });
        }
        res.status(500).json({ error: 'Something went wrong' });
    }
};

const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        const result = await authService.login(email, password);
        res.json(result);
    } catch (err) {
        if (err.message === 'Invalid credentials') {
            return res.status(401).json({ error: err.message });
        }
        res.status(500).json({ error: 'Something went wrong' });
    }
};

module.exports = { signup, login };
