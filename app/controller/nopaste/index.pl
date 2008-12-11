use MENTA::Controller;
use Digest::MD5 ();
use Time::HiRes ();

sub run {
    sql_do(q{CREATE TABLE IF NOT EXISTS nopaste (id VARCHAR(32) PRIMARY KEY, body VARCHAR(255))});

    if (is_post_request()) {
        if (my $body = param('body')) {
            my $id = gen_id();
            sql_prepare_exec('INSERT INTO nopaste (id, body) VALUES (?, ?)', $id, $body);
            redirect(uri_for('nopaste/', {id => $id}));
        } else {
            redirect(uri_for('nopaste/'));
        }
    } else {
        if (my $id = param('id')) {
            my ($row, ) = @{sql_select_all('SELECT id, body FROM nopaste WHERE id=?', $id)};
            if ($row) {
                render_and_print('nopaste/tmpl/show.mt', $row);
            } else {
                render_and_print('nopaste/tmpl/error.mt');
            }
        } else {
            render_and_print('nopaste/tmpl/form.mt');
        }
    }
}

sub gen_id {
    my $unique = $ENV{UNIQUE_ID} || ( [] . rand() );
    Digest::MD5::md5_hex( Time::HiRes::gettimeofday() . $unique );
}

