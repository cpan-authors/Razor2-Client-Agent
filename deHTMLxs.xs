/* $Id: deHTMLxs.xs,v 1.6 2006/02/16 19:16:00 rsoderberg Exp $ */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* try to be compatible with older perls */
/* SvPV_nolen() macro first defined in 5.005_55 */
/* this is slow, not threadsafe, but works */
#include "patchlevel.h"
#if (PATCHLEVEL == 4) || ((PATCHLEVEL == 5) && (SUBVERSION < 55))
static STRLEN nolen_na;
# define SvPV_nolen(sv) SvPV ((sv), nolen_na)
#endif

#include "deHTMLxs.h"

typedef struct mystate {
  int is_xs;
} *Razor2__Preproc__deHTMLxs;

MODULE = Razor2::Preproc::deHTMLxs              PACKAGE = Razor2::Preproc::deHTMLxs

PROTOTYPES: ENABLE


Razor2::Preproc::deHTMLxs
new(class)
    SV *    class
    CODE:
    {

        Newxz(RETVAL, 1, struct mystate);
        RETVAL->is_xs = 1;  /* placeholder, not used now */

    }
    OUTPUT:
        RETVAL

int
is_xs(self)
    Razor2::Preproc::deHTMLxs self;
    CODE:
        RETVAL = 1;
        OUTPUT:
        RETVAL

char *
testxs(self, str)
    Razor2::Preproc::deHTMLxs self;
    char *              str;
    CODE:
        RETVAL = str + 1;
        OUTPUT:
        RETVAL

SV *
isit(self, scalarref)
    Razor2::Preproc::deHTMLxs self;
    SV *        scalarref;
    CODE:
    {
        STRLEN size;
        char * raw;
        SV *  text;

        if (SvROK(scalarref)) {
            text = SvRV(scalarref);
            raw = SvPV(text,size);

            /*  bool CM_PREPROC_is_html(const char *); */
            if (CM_PREPROC_is_html(raw)) {
                RETVAL = newSVpv ("1", 0);
            } else {
                RETVAL = newSVpv ("", 0);
            }
        } else {
                RETVAL = newSVpv ("", 0);
        }
    }
    OUTPUT:
        RETVAL

SV *
doit(self, scalarref)
    Razor2::Preproc::deHTMLxs self;
    SV *        scalarref
    CODE:
    {
        char * cleaned, * raw, * res;
        STRLEN size;
        SV *    text;

        if (SvROK(scalarref)) {
            text = SvRV(scalarref);
            raw = SvPV(text,size);

            if (size == 0) {
                RETVAL = newSVpv ("", 0);
            }
            else {
                Newx(cleaned, size+1, char);
                if ( cleaned &&
                     (res = CM_PREPROC_html_strip(raw, cleaned)) ) {

                    sv_setpv(text, res);

                    SvREFCNT_inc(scalarref);
                    RETVAL = scalarref;
                }
                else {
                    RETVAL = newSVpv ("", 0);
                }
                Safefree(cleaned);
            }
        } else {
                RETVAL = newSVpv ("", 0);
        }

    }
    OUTPUT:
        RETVAL







