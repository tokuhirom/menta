? load_plugin('counter')
<!doctype html>
<h1>わたしのホームページ</h1>
現在の訪問者数は: <?= counter_increment('test') ?>人です。
</html>
