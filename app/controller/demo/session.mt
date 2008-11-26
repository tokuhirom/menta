?= render('header.mt', 'セッションのテスト')

<h1>自分専用カウンターです</h1>

セッションID: <?= session_session_id() ?><br />

カウンタ: <?= session_set("COUNTER", (session_get("COUNTER")||0)+1) ?>

?= render('footer.mt')
