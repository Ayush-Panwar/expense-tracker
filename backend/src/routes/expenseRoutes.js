const express = require('express');
const router = express.Router();
const multer = require('multer');
const auth = require('../middleware/auth');
const { validateExpense } = require('../middleware/validate');
const expenseController = require('../controllers/expenseController');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
});

router.post('/', auth, upload.single('image'), validateExpense, expenseController.createExpense);
router.get('/', auth, expenseController.getExpenses);
router.get('/summary', auth, expenseController.getSummary);
router.get('/changes', auth, expenseController.getChangesSince);
router.delete('/:id', auth, expenseController.deleteExpense);

module.exports = router;
