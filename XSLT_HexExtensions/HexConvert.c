//
//  HexConvert.c
//  XSLT_HexExtensions
//
//  Created by Juan Gatica on 5/20/11.
//  Copyright 2011 Dell KACE. All rights reserved.
//

#include "string.h"
#include "libxslt/extensions.h"
#include "libxslt/functions.h"

#include <libxml/xpath.h>
#include "HexConvert.h"

#define XSLT_HEXCONVERT_URL "http://kace.com/xslt/hexConvert"


void kace_com_xslt_hexConvert_init(void);

static void
xsltConvertToHex(xmlXPathParserContextPtr ctxt,
                    int nargs)
{
    xmlXPathObjectPtr numberObj = NULL;

    xsltTransformContextPtr tctxt;
    long value;
    
    tctxt = xsltXPathGetTransformContext(ctxt);
    if (tctxt == NULL)
        return;
    
    switch (nargs)
    {
        case 1:
            CAST_TO_STRING;
            numberObj = valuePop(ctxt);
            break;
        default:
            XP_ERROR(XPATH_INVALID_ARITY);
    }
    
    sscanf(numberObj->stringval, "%ld", &value);
    
    unsigned char buffer[256];
    
    sprintf((char *) buffer, "%lx", value);
    
    valuePush(ctxt, xmlXPathNewString(buffer));
    
    xmlXPathFreeObject(numberObj);
}

int masks[] = { 0, 0x1, 0x3, 0x7, 0xf, 0x1f, 0x3f, 0x7f, 0xff };

static void xsltExtractBitField(xmlXPathParserContextPtr ctxt,
                                int nargs)
{
    xmlXPathObjectPtr bitFieldObject = NULL;
    xmlXPathObjectPtr fieldOffsetObject = NULL;
    xmlXPathObjectPtr fieldLengthObject = NULL;

    xsltTransformContextPtr tctxt;
    long bitField;
    int fieldOffset, fieldLength, value;
    
    tctxt = xsltXPathGetTransformContext(ctxt);
    if (tctxt == NULL)
        return;
    
    switch (nargs)
    {
        case 3:
            CAST_TO_STRING;
            fieldLengthObject = valuePop(ctxt);
            
            CAST_TO_STRING;
            fieldOffsetObject = valuePop(ctxt);
            
            CAST_TO_STRING;
            bitFieldObject = valuePop(ctxt);
            break;
        default:
            XP_ERROR(XPATH_INVALID_ARITY);
    }
    
    sscanf((char *) bitFieldObject->stringval, "%ld", &bitField);
    sscanf((char *) fieldOffsetObject->stringval, "%d", &fieldOffset);
    sscanf((char *) fieldLengthObject->stringval, "%d", &fieldLength);
    
    value = (bitField >> fieldOffset) & masks[fieldLength];
    
    unsigned char buffer[256];
    
    sprintf((char *) buffer, "%d", value);
    
    valuePush(ctxt, xmlXPathNewString(buffer));
    
    xmlXPathFreeObject(bitFieldObject);
    xmlXPathFreeObject(fieldLengthObject);
    xmlXPathFreeObject(fieldOffsetObject);
}

static const char  table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const int   BASE64_INPUT_SIZE = 57;

int isbase64(char c)
{
    return c && strchr(table, c) != NULL;
}

inline char value(char c)
{
    const char *p = strchr(table, c);
    if(p) {
        return p-table;
    } else {
        return 0;
    }
}

int UnBase64(unsigned char *dest, const unsigned char *src, int srclen)
{
    *dest = 0;
    if(*src == 0) 
    {
        return 0;
    }
    unsigned char *p = dest;
    do
    {
        
        char a = value(src[0]);
        char b = value(src[1]);
        char c = value(src[2]);
        char d = value(src[3]);
        *p++ = (a << 2) | (b >> 4);
        *p++ = (b << 4) | (c >> 2);
        *p++ = (c << 6) | d;
        if(!isbase64(src[1])) 
        {
            p -= 2;
            break;
        } 
        else if(!isbase64(src[2])) 
        {
            p -= 2;
            break;
        } 
        else if(!isbase64(src[3])) 
        {
            p--;
            break;
        }
        src += 4;
        while(*src && (*src == 13 || *src == 10)) src++;
    }
    while(srclen-= 4);
    *p = 0;
    return p-dest;
}

void escapeString(unsigned char *inputString, unsigned char *outputString)
{
    int i;
    unsigned char *pt = outputString;
    
    for (i = 0; inputString[i] != '\0'; i++)
    {
        switch (inputString[i])
        {
            case '\n':
            case '\t':
            case '"':
                *pt++ = '\\';
                *pt++ = inputString[i];
                break;
                
            default:
                *pt++ = inputString[i];
                break;
        }
    }
    *pt++ = '\0';
}

static void xsltDecodeBase64StringEscaped(xmlXPathParserContextPtr ctxt,
                                int nargs)
{
    xmlXPathObjectPtr inputStringObject = NULL;
    
    xsltTransformContextPtr tctxt;
    int fieldOffset, fieldLength, value;
    
    tctxt = xsltXPathGetTransformContext(ctxt);
    if (tctxt == NULL)
        return;
    
    switch (nargs)
    {
        case 1:
            CAST_TO_STRING;
            inputStringObject = valuePop(ctxt);
            break;
        default:
            XP_ERROR(XPATH_INVALID_ARITY);
    }
    
    unsigned char encodedString[512];
    unsigned char unencodedString[512];
    unsigned char escapedString[1024];
    int encodedStringLength = strlen(inputStringObject->stringval);
    
    strcpy(encodedString, inputStringObject->stringval);
    switch (encodedStringLength % 4)
    {
        case 0:
            break;
        case 1:
            strcat(encodedString, "===");
            break;
        case 2:
            strcat(encodedString, "==");
            break;
        case 3:
            strcat(encodedString, "=");
            break;
    }
    
    UnBase64(unencodedString, encodedString, strlen(encodedString));
    
    escapeString(unencodedString, escapedString);
    
    valuePush(ctxt, xmlXPathNewString(escapedString));
    
    xmlXPathFreeObject(inputStringObject);
}

static void xsltEscapeSpecialCharacters(xmlXPathParserContextPtr ctxt,
                                          int nargs)
{
    xmlXPathObjectPtr inputStringObject = NULL;
    
    xsltTransformContextPtr tctxt;
    int fieldOffset, fieldLength, value;
    
    tctxt = xsltXPathGetTransformContext(ctxt);
    if (tctxt == NULL)
        return;
    
    switch (nargs)
    {
        case 1:
            CAST_TO_STRING;
            inputStringObject = valuePop(ctxt);
            break;
        default:
            XP_ERROR(XPATH_INVALID_ARITY);
    }
    
    unsigned char escapedString[1024];
    
    escapeString(inputStringObject->stringval, escapedString);

    valuePush(ctxt, xmlXPathNewString(escapedString));
    
    xmlXPathFreeObject(inputStringObject);
}

/**
 * xsltExtInitFunction:
 * @ctxt:  an XSLT transformation context
 * @URI:  the namespace URI for the extension
 *
 * A function called at initialization time of an XSLT
 * extension module
 *
 * Returns a pointer to the module specific data for this
 * transformation
 */
void kace_com_xslt_hexConvert_init(void)
{
    xsltRegisterExtModuleFunction((const xmlChar *) "convertToHex",
                                  (const xmlChar *) XSLT_HEXCONVERT_URL,
                                  xsltConvertToHex);
    xsltRegisterExtModuleFunction((const xmlChar *) "extractField",
                                  (const xmlChar *) XSLT_HEXCONVERT_URL,
                                  xsltExtractBitField);
    xsltRegisterExtModuleFunction((const xmlChar *) "base64DecodeEscaped",
                                  (const xmlChar *) XSLT_HEXCONVERT_URL,
                                  xsltDecodeBase64StringEscaped);
    xsltRegisterExtModuleFunction((const xmlChar *) "escapeSpecialCharacters",
                                  (const xmlChar *) XSLT_HEXCONVERT_URL,
                                  xsltEscapeSpecialCharacters);
}

