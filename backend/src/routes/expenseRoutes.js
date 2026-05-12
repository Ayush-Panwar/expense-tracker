const express = require('express');
const router = express.Router();
const multer = require('multer');
const auth = require('../middleware/auth');
const { validateExpense } = require('../middleware/validate');
const expenseController = require('../controllers/expenseController');

const upload = multer({ storage: multer.memoryStorage() });

router.post('/', auth, upload.single('image'), validateExpense, expenseController.createExpense);
router.get('/', auth, expenseController.getExpenses);
router.delete('/:id', auth, expenseController.deleteExpense);

module.exports = router;