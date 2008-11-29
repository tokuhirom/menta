?= render('header.mt', 'セッションのテスト')

<h1>自分専用カウンターです</h1>
<table>
    <tr><td>セッションID</td><td><?= session_session_id() ?></td></tr>
    <tr><td>カウンタ</td><td><?= session_set("COUNTER", (session_get("COUNTER")||0)+1) ?></td></tr>
    <tr><td>セッション状態管理クラス</td><td><?= session_state_class() ?></td></tr>
    <tr><td>セッション保存クラス</td><td><?= session_store_class() ?></td></tr>
</table>

?= render('footer.mt')
