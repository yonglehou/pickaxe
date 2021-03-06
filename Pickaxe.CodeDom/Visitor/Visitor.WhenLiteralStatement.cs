﻿/* Copyright 2015 Brock Reeve
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

using Pickaxe.Sdk;
using System;
using System.CodeDom;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Pickaxe.CodeDom.Visitor
{
    public partial class CodeDomGenerator : IAstVisitor
    {
        public void Visit(WhenLiteralStatement statement)
        {
            CodeStatementCollection collection = new CodeStatementCollection();
            var arg = VisitChild(statement.Literal);

            var condition = new CodeConditionStatement();
            if (arg.Tag != null) //this is a null literal
            {
                condition.Condition = new CodeBinaryOperatorExpression(new CodeVariableReferenceExpression("var"), CodeBinaryOperatorType.IdentityEquality, new CodePrimitiveExpression(null));
            }
            else
            {
                var preCondition = new CodeBinaryOperatorExpression(new CodeVariableReferenceExpression("var"), CodeBinaryOperatorType.IdentityInequality, new CodePrimitiveExpression(null));
                condition.Condition = new CodeBinaryOperatorExpression(preCondition, CodeBinaryOperatorType.BooleanAnd, new CodeMethodInvokeExpression(new CodeVariableReferenceExpression("var"), "Equals", arg.CodeExpression));
            }

            var then = VisitChild(statement.Then);
            condition.TrueStatements.Add(new CodeMethodReturnStatement(then.CodeExpression));
            _codeStack.Peek().Tag = then.Tag;
            _codeStack.Peek().ParentStatements.Add(condition);
        }
    }
}
