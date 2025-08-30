const express = require('express');
const app = express();
app.get('/', (req,res)=>res.send('OK'));
app.get('/assets/public/favicon_js.ico', (req,res)=>res.sendStatus(200));
app.listen(3000, ()=>console.log('listening on 3000'));
