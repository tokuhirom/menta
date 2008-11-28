? my $count = counter_increment('test')
<!doctype html>
<title>MENTA カウンター</title>

<h1>わたしのホームページ</h1>
<p>
? if ($count =~ /^10+$/) {
<strong>おめでとうございます！！！</strong>
? }
あなたは世界で <strong><?= $count ?> 人目</strong>のスピリチュアルな訪問者です。</p>
<p>次のキリ番は <?= 10 ** int(log($count) / log(10)) ?>0 です！</p>
