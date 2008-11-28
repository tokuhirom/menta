?= render('header.mt', 'セッションのテスト')

<h1>自分専用カウンターです</h1>
<dl>
 <dt>セッションID</dt>
  <dd><?= session_session_id() ?></dd>
 <dt>カウンタ</dt>
  <dd><?= session_set("COUNTER", (session_get("COUNTER")||0)+1) ?></dd>
</dl>

?= render('footer.mt')
