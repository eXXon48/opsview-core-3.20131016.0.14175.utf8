#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

int ndo_unescape_buffer( char *buffer ) {
	int x=0;
	int y=0;
	int len=0;

	if(buffer==NULL)
		return;

    len=(int)strlen(buffer);

	for( x=0; x < len; x++ ) {
        if(buffer[x]=='\\') {
            if(buffer[x+1]=='n')
                buffer[y++]='\n';
            else if(buffer[x+1]=='\\')
                buffer[y++]='\\';
            else if(buffer[x+1]=='t')
                buffer[y++]='\t';
            else if(buffer[x+1]=='r')
                buffer[y++]='\r';
            else
                buffer[y++]=buffer[x+1];

            x++;
        }
        else {
            buffer[y++]=buffer[x];
        }
    }

	/* terminate string */
	buffer[y]=0;

    return y;
}

#define BLOCK_HEADER 0
#define BLOCK_EVENTS 1
#define BLOCK_EVENT 2
#define BLOCK_FOOTER 3
#define BLOCK_IGNORE_EVENT 4
#define BLOCK_EVENT_STARTED 5
#define BLOCK_EVENT_ENDED 6

int last_999(const char *buf, const size_t bytes_read) {
    char *l999 = "\n999\n";
    char *ptr, *last = NULL;

    ptr = (char*)buf;
    while((ptr = strstr(ptr, l999))) {
        last = ptr++; 
    }
    if ( ! last ) return 0;
    return bytes_read - (last - buf) - 5;
}

PerlIO *fh;
size_t prev_pos = 0;
size_t bytes_left = 0;
int automated_tests = 0;
int first_read = 1;

void parser_reset_iterator() {
    first_read = 1;
    prev_pos = 0;
    bytes_left = 0;
    if (fh) PerlIO_close( fh );
}

SV * parse_in_chunks(char * filepath, size_t filesize) {
    char *buf;
    size_t bytes_read = 0;
    int max_buf = 1000;
    char *err_msg;
    int block = BLOCK_HEADER;
    int cur_event_type = 0;
    int event_type = 0;
    char event_block = 0;
    char *brnl, *breq;
    AV * data;
    AV * datawrapper;
    AV * events;
    char *line;
    char * nl = "\n";
    char * eq = "=";
    int rewind_pos = 0;
    size_t cur_fpos = 0;
    SV * pbuf;
    SV * pmax_buf;

    AV * HANDLERS = get_av("Opsview::Utils::NDOLogsImporter::HANDLERS", 0);
    AV * INPUT_DATA_TYPE = get_av("Opsview::Utils::NDOLogsImporter::INPUT_DATA_TYPE", 0);

    int init_last_pos;
    int init_block;

    if ( first_read ) {
        if ( ! ( fh = PerlIO_open( filepath, "rb" ) ) ) {
            croak("Could not open file: %s\n", strerror(errno));
        }

        bytes_left = filesize;
        init_last_pos = prev_pos = first_read = 0;
        init_block = block = BLOCK_HEADER;
    } else {
        init_block = block = BLOCK_EVENTS;
        init_last_pos = prev_pos;
    }

    read_begin:


    brnl = NULL;
    breq = NULL;

    pbuf = get_sv("Opsview::Utils::NDOLogsImporter::PARSE_BUF", 0);
    pmax_buf = get_sv("Opsview::Utils::NDOLogsImporter::MAX_BUF_SIZE", 0);

    buf = SvPVX(pbuf);
    max_buf = SvIVX(pmax_buf);

    if ( max_buf < 1024 * 1024 && ! automated_tests ) {
        max_buf = 1024*1024;
        SvIV_set( pmax_buf, max_buf );
        SvGROW( pbuf, max_buf + 1);
        SvCUR_set( pbuf, max_buf);
    }

    if ( bytes_left > 0 ) {

        bytes_read = PerlIO_read(fh, buf + prev_pos, max_buf-prev_pos);
        cur_fpos = PerlIO_tell(fh);

        if ( bytes_read < 0 ) {
            err_msg = strerror(errno);

            PerlIO_close( fh );

            croak("Could not read file: %s\n", err_msg);
        }

        bytes_left -= bytes_read;

        events = (AV *)sv_2mortal((SV *)newAV());

        rewind_pos = last_999(buf+prev_pos, bytes_read);
        prev_pos = bytes_read + prev_pos - rewind_pos;
        buf[prev_pos] = '\0';

        // avg ratio events:file_size = 0.21%
        if ( prev_pos > 1000 ) {
            av_extend( events, (int)(prev_pos * 0.0021) );
        }


        for ( line = strtok_r(buf, nl, &brnl); line != NULL; line = strtok_r(NULL, nl, &brnl) )
        {
            switch(block) {
                case BLOCK_HEADER:
                    {
                        if ( strEQ(line, "STARTDATADUMP") ) {
                            block = BLOCK_EVENTS;
                        }
                    }
                    break;

                case BLOCK_EVENTS:
                    {
                        if ( strEQ(line, "1000") ) { /* NDO_API_ENDDATADUMP */
                            block = BLOCK_FOOTER;
                            continue;
                        }

                        cur_event_type = atoi(line);

                        /* ignore events we are not handling */
                        if ( !  av_exists(HANDLERS, cur_event_type) ) {
                            block = BLOCK_IGNORE_EVENT;
                            continue;
                        }

                        event_block = BLOCK_EVENT_STARTED;
                        if ( cur_event_type != event_type ) {
                            datawrapper = (AV *)sv_2mortal((SV *)newAV());
                            data = (AV *)sv_2mortal((SV *)newAV());

                            av_push( events, newSViv( cur_event_type ) );
                            av_push( datawrapper, newRV( (SV *)data ) );
                            av_push( events, newRV( (SV *)datawrapper ) );

                            event_type = cur_event_type;
                        } else {
                            data = (AV *)sv_2mortal((SV *)newAV());

                            av_push( datawrapper, newRV( (SV *)data ) );
                        }

                        block = BLOCK_EVENT; 
                    }
                    break;

                case BLOCK_EVENT:
                    {
                        if ( strEQ(line, "999") ) { /* NDO_API_ENDDATA */
                            block = BLOCK_EVENTS;
                            event_block = BLOCK_EVENT_ENDED;
                        } else {
                            char *k;
                            char *v;
                            int key;
                            int key_type = 0;
                            int v_len = 0;

                            k = strtok_r(line, eq, &breq); 
                            v = strtok_r(NULL, "\0", &breq);

                            key = atoi(k);
                            /* invalid key, skip parsing */
                            if ( key == 0 ) {
                                goto remove_invalid;
                            }

                            SV ** const k_type = av_fetch(INPUT_DATA_TYPE, key, 0 ); 
                            if ( k_type ) {
                                key_type = SvIVx( *k_type );
                            }

                            if ( v ) {
                                if ( key_type & 1 ) {
                                   v_len = ndo_unescape_buffer( v ); 
                                } else {
                                    v_len = strlen(v);
                                }
                            }

                            if ( key_type & 2 ) {
                                AV * datanstptr;
                                SV ** const datanst = av_fetch(data, key, 0 ); 
                                if ( datanst ) {
                                    datanstptr = (AV *)SvRV( *datanst );
                                } else {
                                    datanstptr = (AV *)sv_2mortal((SV *)newAV());

                                    av_store( data, key, newRV( (SV *)datanstptr ) );
                                }

                                if ( v ) { 
                                    av_push( datanstptr, newSVpvn(v, v_len) );
                                } else {
                                    av_push( datanstptr, newSVpvn("", 0) );
                                }

                            } else {
                                if ( v ) { 
                                    av_store( data, key, newSVpvn(v, v_len) );
                                } else {
                                    av_store( data, key, newSVpvn("", 0) );
                                }
                            }
                        }
                    }
                    break;

                case BLOCK_FOOTER:
                    {
                        if ( strEQ(line, "GOODBYE") ) {
                            block = BLOCK_HEADER;
                        }
                    }
                    break;

                case BLOCK_IGNORE_EVENT:
                    {
                        if ( strEQ(line, "999") ) { /* NDO_API_ENDDATA */
                            block = BLOCK_EVENTS; // go back to EVENTS
                            continue;
                        }
                    }
                    break;
            }
        };

        /* there were some events */
        if ( event_block != BLOCK_HEADER ) {
            if ( event_block != BLOCK_EVENT_ENDED ) {
                remove_invalid:
                    av_pop( datawrapper );
            }

            /* remove whole block if the last block has no events */
            if ( av_len( datawrapper ) == -1 ) {
                av_pop( events );
                av_pop( events );
            }
        }


        if ( av_len(events) > 0 ) {
            if ( rewind_pos > 0 && cur_fpos < filesize ) {
                memmove(buf, buf+prev_pos+1, rewind_pos-1);
            }

            prev_pos = rewind_pos - 1;

            return newRV_inc((SV *) events);
        } else {

            if ( cur_fpos < filesize && event_block != BLOCK_HEADER && event_block != BLOCK_EVENT_ENDED ) {
                int new_max_buf = max_buf * 2;

                SvIV_set( pmax_buf, new_max_buf );
                SvGROW( pbuf, new_max_buf + 1);
                SvCUR_set( pbuf, new_max_buf);
                //start again as previous buffer would be tokenized already
                prev_pos = 0;
                block = init_block;
                event_type = 0;


                PerlIO_close( fh );
                if ( ! ( fh = PerlIO_open( filepath, "rb" ) ) ) {
                    croak("Could not re-open file: %s\n", strerror(errno));
                }
                PerlIO_seek(fh, cur_fpos-bytes_read-init_last_pos, SEEK_SET);
                bytes_left += bytes_read + init_last_pos;

                goto read_begin; 
            }
        }
    }

    parser_reset_iterator();

    return &PL_sv_undef;
}



MODULE = Opsview::Utils::NDOLogsImporter::XS		PACKAGE = Opsview::Utils::NDOLogsImporter::XS		

PROTOTYPES: DISABLE

BOOT:
if ( getenv("AUTOMATED_TESTS") ) {
    automated_tests = 1;
}

void
timeval (ts)
        char *ts
	PREINIT:
        const char *mil;
        int s=0;
        int m=0;
	PPCODE:
    {
        EXTEND(SP, 2);

        if ( ts ) {
            s = atoi(ts);

            mil = strchr(ts, '.');

            if ( mil != NULL ) {
                m = atoi(mil+1);
            }
        }

        PUSHs(sv_2mortal( newSViv(s) ));
        PUSHs(sv_2mortal( newSViv(m) ));
    }

int
ndo_unescape_buffer (buffer)
	char *	buffer

SV *
parse_in_chunks (filepath, filesize)
	char *	filepath
	size_t	filesize

void
parser_reset_iterator()

