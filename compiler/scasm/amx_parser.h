/* AMX Assembler
 * Copyright (C)2004 David "BAILOPAN" Anderson
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Version: $Id$
 */

#ifndef _INCLUDE_PARSER_H
#define _INCLUDE_PARSER_H

void StringBreak(std::string &Source, std::string &Left, std::string &Right);
int FindArguments(std::string &text, std::vector<std::string*> &List, int &end);
int FindSymbol(std::string &text, const std::string &sym, int startPos);
void ProcessDirective(std::string &text);
void StripComments(std::string &text);
void Strip(std::string &text);
char isletter(char c);
char literal(char c);
char expr(char c);

#endif //_INCLUDE_PARSER_H
