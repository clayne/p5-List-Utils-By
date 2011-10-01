#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

struct sort_elem {
    SV *key;
    SV *orig;
};

static I32
sv_cmp_str_asc(pTHX_ SV *sv1, SV *sv2)
{
    struct sort_elem *se1, *se2;

    se1 = (struct sort_elem*)SvIV(sv1);
    se2 = (struct sort_elem*)SvIV(sv2);

    return sv_cmp_locale(se1->key, se2->key);
}

static I32
sv_cmp_str_desc(pTHX_ SV *sv1, SV *sv2)
{
    struct sort_elem *se1, *se2;

    se1 = (struct sort_elem*)SvIV(sv1);
    se2 = (struct sort_elem*)SvIV(sv2);

    return sv_cmp_locale(se2->key, se1->key);
}

static I32
sv_cmp_number_asc(pTHX_ SV *sv1, SV *sv2)
{
    struct sort_elem *se1, *se2;
    IV key1, key2;

    se1 = (struct sort_elem*)SvIV(sv1);
    se2 = (struct sort_elem*)SvIV(sv2);

    key1 = SvIV(se1->key);
    key2 = SvIV(se2->key);

    return (key1 > key2)
           ? 1 : (key1 == key2)
           ? 0 : -1;
}

static I32
sv_cmp_number_desc(pTHX_ SV *sv1, SV *sv2)
{
    struct sort_elem *se1, *se2;
    IV key1, key2;

    se1 = (struct sort_elem*)SvIV(sv1);
    se2 = (struct sort_elem*)SvIV(sv2);

    key1 = SvIV(se2->key);
    key2 = SvIV(se1->key);

    return (key1 > key2)
           ? 1 : (key1 == key2)
           ? 0 : -1;
}

MODULE = List::UtilsBy::XS        PACKAGE = List::UtilsBy::XS

void
sort_by (code, ...)
    SV *code
PROTOTYPE: &@
ALIAS:
    sort_by     = 0
    rev_sort_by = 1
CODE:
{
    dMULTICALL;
    GV *gv;
    HV *stash;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    int i;
    AV *tmps;
    struct sort_elem *elems;

    if (items <= 1) {
        XSRETURN_EMPTY;
    }

    tmps = (AV *)sv_2mortal((SV *)newAV());

    cv = sv_2cv(code, &stash, &gv, 0);
    if (cv == Nullcv) {
       croak("Not a subroutine reference");
    }

    PUSH_MULTICALL(cv);
    SAVESPTR(GvSV(PL_defgv));

    Newx(elems, items - 1, struct sort_elem);

    for (i = 1; i < items; i++) {
        struct sort_elem *elem = &elems[i - 1];

        GvSV(PL_defgv) = args[i];
        MULTICALL;

        elem->key  = newSVsv(*PL_stack_sp);
        elem->orig = newSVsv(args[i]);

        av_push(tmps, newSViv((IV)elem));
    }

    POP_MULTICALL;

    if (ix) {
        sortsv(AvARRAY(tmps), av_len(tmps) + 1, sv_cmp_str_desc);
    } else {
        sortsv(AvARRAY(tmps), av_len(tmps) + 1, sv_cmp_str_asc);
    }

    for (i = 1; i < items; i++) {
        struct sort_elem *elem;
        elem  = (struct sort_elem *)SvIV(*av_fetch(tmps, i-1, 0));
        ST(i-1) = sv_2mortal(elem->orig);
        (void)sv_2mortal(elem->key);
    }

    Safefree(elems);

    XSRETURN(items - 1);
}

void
nsort_by (code, ...)
    SV *code
PROTOTYPE: &@
ALIAS:
    nsort_by     = 0
    rev_nsort_by = 1
CODE:
{
    dMULTICALL;
    GV *gv;
    HV *stash;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    int i;
    AV *tmps;
    struct sort_elem *elems;

    if (items <= 1) {
        XSRETURN_EMPTY;
    }

    tmps = (AV *)sv_2mortal((SV *)newAV());

    cv = sv_2cv(code, &stash, &gv, 0);
    if (cv == Nullcv) {
       croak("Not a subroutine reference");
    }

    PUSH_MULTICALL(cv);
    SAVESPTR(GvSV(PL_defgv));

    Newx(elems, items - 1, struct sort_elem);

    for (i = 1; i < items; i++) {
        struct sort_elem *elem = &elems[i - 1];

        GvSV(PL_defgv) = args[i];
        MULTICALL;

        elem->key  = newSVsv(*PL_stack_sp);
        elem->orig = newSVsv(args[i]);

        av_push(tmps, newSViv((IV)elem));
    }

    POP_MULTICALL;

    if (ix) {
        sortsv(AvARRAY(tmps), av_len(tmps) + 1, sv_cmp_number_desc);
    } else {
        sortsv(AvARRAY(tmps), av_len(tmps) + 1, sv_cmp_number_asc);
    }

    for (i = 1; i < items; i++) {
        struct sort_elem *elem;
        elem  = (struct sort_elem *)SvIV(*av_fetch(tmps, i-1, 0));
        ST(i-1) = sv_2mortal(elem->orig);
        (void)sv_2mortal(elem->key);
    }

    Safefree(elems);

    XSRETURN(items - 1);
}

void
min_by (code, ...)
    SV *code
PROTOTYPE: &@
ALIAS:
    min_by = 0
    max_by = 1
CODE:
{
    dMULTICALL;
    GV *gv;
    HV *stash;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    int i;
    AV *tmps;
    IV max;
    IV ret_count = 0;
    struct sort_elem *elems, *first;

    if (items <= 1) {
        XSRETURN_EMPTY;
    }

    tmps = (AV *)sv_2mortal((SV *)newAV());

    cv = sv_2cv(code, &stash, &gv, 0);
    if (cv == Nullcv) {
       croak("Not a subroutine reference");
    }

    PUSH_MULTICALL(cv);
    SAVESPTR(GvSV(PL_defgv));

    Newx(elems, items - 1, struct sort_elem);

    for (i = 1; i < items; i++) {
        struct sort_elem *elem = &elems[i - 1];

        GvSV(PL_defgv) = args[i];
        MULTICALL;

        elem->key  = newSVsv(*PL_stack_sp);
        elem->orig = newSVsv(args[i]);

        av_push(tmps, newSViv((IV)elem));
    }

    POP_MULTICALL;

    if (ix) {
        sortsv(AvARRAY(tmps), av_len(tmps) + 1, sv_cmp_number_desc);
    } else {
        sortsv(AvARRAY(tmps), av_len(tmps) + 1, sv_cmp_number_asc);
    }

    first = (struct sort_elem *)SvIV(*av_fetch(tmps, 0, 0));
    max   = SvIV(first->key);
    ST(0) = sv_2mortal(first->orig);
    (void)sv_2mortal(first->key);
    ret_count++;

    if (GIMME_V != G_ARRAY) {
        goto ret;
    }

    for (i = 2; i < items; i++) {
        struct sort_elem *elem;
        elem  = (struct sort_elem *)SvIV(*av_fetch(tmps, i-1, 0));

        if (max == SvIV(elem->key)) {
            ST(ret_count) = sv_2mortal(elem->orig);
            (void)sv_2mortal(elem->key);
            ret_count++;
        } else {
            goto ret;
        }
    }

 ret:
    Safefree(elems);
    XSRETURN(ret_count);
}

void
uniq_by (code, ...)
    SV *code
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    GV *gv;
    HV *stash;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    int i;
    AV *tmps;
    HV *rh;

    if (items <= 1) {
        XSRETURN_EMPTY;
    }

    tmps = (AV *)sv_2mortal((SV *)newAV());
    rh = (HV *)sv_2mortal((SV *)newHV());

    cv = sv_2cv(code, &stash, &gv, 0);
    if (cv == Nullcv) {
       croak("Not a subroutine reference");
    }

    PUSH_MULTICALL(cv);
    SAVESPTR(GvSV(PL_defgv));

    for (i = 1; i < items; i++) {
        STRLEN len;
        char *str;

        GvSV(PL_defgv) = args[i];
        MULTICALL;

        str = SvPV(*PL_stack_sp, len);
        if (!hv_exists(rh, str, len)) {
            av_push(tmps, newSVsv(args[i]));
            (void)hv_store(rh, str, len, newSViv(1), 0);
        }
    }

    POP_MULTICALL;

    for (i = 0; i <= av_len(tmps); i++) {
        ST(i) = *av_fetch(tmps, i, 0);
    }

    XSRETURN(av_len(tmps) + 1);
}

void
partition_by (code, ...)
    SV *code
PROTOTYPE: &@
CODE:
{
    dMULTICALL;
    GV *gv;
    HV *stash;
    I32 gimme = G_SCALAR;
    SV **args = &PL_stack_base[ax];
    int i;
    HV *rh;
    HE *iter = NULL;

    if (items <= 1) {
        XSRETURN_EMPTY;
    }

    rh = (HV *)sv_2mortal((SV *)newHV());

    cv = sv_2cv(code, &stash, &gv, 0);
    if (cv == Nullcv) {
       croak("Not a subroutine reference");
    }

    PUSH_MULTICALL(cv);
    SAVESPTR(GvSV(PL_defgv));

    for (i = 1; i < items; i++) {
        STRLEN len;
        char *str;

        GvSV(PL_defgv) = args[i];
        MULTICALL;

        str = SvPV(*PL_stack_sp, len);
        if (!hv_exists(rh, str, len)) {
            AV* av = (AV *)sv_2mortal((SV *)newAV());
            av_push(av, newSVsv(args[i]));
            (void)hv_store(rh, str, len, newRV_inc((SV *)av), 0);
        } else {
            AV *av = (AV *)SvRV(*hv_fetch(rh, str, len, 0));
            av_push(av, newSVsv(args[i]));
        }
    }

    POP_MULTICALL;

    hv_iterinit(rh);

    i = 0;
    while ( (iter = hv_iternext( rh )) != NULL ) {
          ST(i) = hv_iterkeysv(iter);
          i++;
          ST(i) = hv_iterval(rh, iter);
          i++;
    }

    XSRETURN(i);
}
