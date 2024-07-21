/* @(#)xdr_mem.c	2.1 88/07/29 4.0 RPCSRC */
/*
 * Copyright (c) 2010, Oracle America, Inc.
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in
 *       the documentation and/or other materials provided with the
 *       distribution.
 *
 *     * Neither the name of the "Oracle America, Inc." nor the names of
 *       its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#if !defined(lint) && defined(SCCSIDS)
static char sccsid[] = "@(#)xdr_mem.c 1.19 87/08/11 Copyr 1984 Sun Micro";
#endif

/*
 * xdr_mem.h, XDR implementation using memory buffers.
 *
 * If you have some data to be interpreted as external data representation
 * or to be converted to external data representation in a memory buffer,
 * then this is the package for you.
 *
 */


#include "types.h"
#include "xdr.h"
#include <stdio.h>
#include <string.h>
#include <limits.h>

static bool_t	xdrmem_getlong(XDR *, long *);
static bool_t	xdrmem_putlong(XDR *, const long *);
static bool_t	xdrmem_getbytes(XDR *, caddr_t, u_int);
static bool_t	xdrmem_putbytes(XDR *, const char *, u_int);
static u_int	xdrmem_getpos(const XDR *);
static bool_t	xdrmem_setpos(XDR *, u_int);
static int32_t *	xdrmem_inline(XDR *, unsigned int);
static void	xdrmem_destroy(XDR *);

static struct	XDR::xdr_ops xdrmem_ops = {
	xdrmem_getlong,
	xdrmem_putlong,
	xdrmem_getbytes,
	xdrmem_putbytes,
	xdrmem_getpos,
	xdrmem_setpos,
	xdrmem_inline,
	xdrmem_destroy
};

/* Copyright The GROMACS Authors */
static uint32_t xdr_swapbytes(uint32_t x)
{
    uint32_t y;
    int          i;
    char*        px = reinterpret_cast<char*>(&x);
    char*        py = reinterpret_cast<char*>(&y);

    for (i = 0; i < 4; i++)
    {
        py[i] = px[3 - i];
    }

    return y;
}

/* Copyright The GROMACS Authors */
static uint32_t xdr_htonl(uint32_t x)
{
    short s = 0x0F00;
    if (*(reinterpret_cast<char*>(&s)) == static_cast<char>(0x0F))
    {
        /* bigendian, do nothing */
        return x;
    }
    else
    {
        /* smallendian,swap bytes */
        return xdr_swapbytes(x);
    }
}

/* Copyright The GROMACS Authors */
static uint32_t xdr_ntohl(uint32_t x)
{
    short s = 0x0F00;
    if (*(reinterpret_cast<char*>(&s)) == static_cast<char>(0x0F))
    {
        /* bigendian, do nothing */
        return x;
    }
    else
    {
        /* smallendian, swap bytes */
        return xdr_swapbytes(x);
    }
}

/*
 * The procedure xdrmem_create initializes a stream descriptor for a
 * memory buffer.
 */
void
xdrmem_create(
	XDR *xdrs,
	caddr_t addr,
	u_int size,
	enum xdr_op op)
{

	xdrs->x_op = op;
	xdrs->x_ops = &xdrmem_ops;
	xdrs->x_private = xdrs->x_base = addr;
	xdrs->x_handy = (size > INT_MAX) ? INT_MAX : size; /* XXX */
}

static void
xdrmem_destroy(XDR *xdrs)
{
}

static bool_t
xdrmem_getlong(XDR *xdrs, long *lp)
{

	if (xdrs->x_handy < BYTES_PER_XDR_UNIT)
		return (FALSE);
	else
		xdrs->x_handy -= BYTES_PER_XDR_UNIT;
	*lp = (long)(int32_t)xdr_ntohl(*((uint32_t *)(xdrs->x_private)));
	xdrs->x_private = (char *)xdrs->x_private + BYTES_PER_XDR_UNIT;
	return (TRUE);
}

static bool_t
xdrmem_putlong(XDR *xdrs, const long *lp)
{

	if (xdrs->x_handy < BYTES_PER_XDR_UNIT)
		return (FALSE);
	else
		xdrs->x_handy -= BYTES_PER_XDR_UNIT;
	*(int32_t *)xdrs->x_private = (int32_t)xdr_htonl((uint32_t)(*lp));
	xdrs->x_private = (char *)xdrs->x_private + BYTES_PER_XDR_UNIT;
	return (TRUE);
}

static bool_t
xdrmem_getbytes(XDR *xdrs, caddr_t addr, u_int len)
{

	if ((u_int)xdrs->x_handy < len)
		return (FALSE);
	else
		xdrs->x_handy -= len;
	memmove(addr, xdrs->x_private, len);
	xdrs->x_private = (char *)xdrs->x_private + len;
	return (TRUE);
}

static bool_t
xdrmem_putbytes(XDR *xdrs, const caddr_t addr, u_int len)
{

	if ((u_int)xdrs->x_handy < len)
		return (FALSE);
	else
		xdrs->x_handy -= len;
	memmove(xdrs->x_private, addr, len);
	xdrs->x_private = (char *)xdrs->x_private + len;
	return (TRUE);
}

static u_int
xdrmem_getpos(const XDR *xdrs)
{
/*
 * 11/3/95 - JRG - Rather than recast everything for 64 bit, just convert
 * pointers to longs, then cast to int.
 */
	return (u_int)((u_long)xdrs->x_private - (u_long)xdrs->x_base);
}

static bool_t
xdrmem_setpos(XDR *xdrs, u_int pos)
{
	caddr_t newaddr = xdrs->x_base + pos;
	caddr_t lastaddr = (char *)xdrs->x_private + xdrs->x_handy;

	if ((long)newaddr > (long)lastaddr)
		return (FALSE);
	xdrs->x_private = newaddr;
	xdrs->x_handy = (int)((long)lastaddr - (long)newaddr);
	return (TRUE);
}

static int32_t *
xdrmem_inline(XDR *xdrs, unsigned int len)
{
	int32_t *buf = 0;

	if (len >= 0 && xdrs->x_handy >= len) {
		xdrs->x_handy -= len;
		buf = (int32_t *) xdrs->x_private;
		xdrs->x_private = (char *)xdrs->x_private + len;
	}
	return (buf);
}
