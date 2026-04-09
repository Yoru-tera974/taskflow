const express = require('express');
const app = express();

app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

app.listen(8080, () => {
    console.log('TaskFlow API running on port 8080');
});