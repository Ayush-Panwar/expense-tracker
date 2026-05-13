const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { validateSignup, validateLogin } = require('../middleware/validate');

router.post('/signup', validateSignup, authController.signup);
router.post('/login', validateLogin, authController.login);

module.exports = router;
