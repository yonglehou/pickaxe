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

using NUnit.Framework;
using Pickaxe.Emit;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PickAxe.Tests
{
    [TestFixture]
    public class CodeGen
    {
        [Test]
        public void TestCodeRunner()
        {
        }
       
        [Test]
        public void BasicCodeGenTest()
        {
              var input = @"

create buffer b(t datetime)

var temp = 1

 insert into b
 select getdate()
 
 select *
 from b
 where b.t > '5/8/2002'

";

            var compiler = new Compiler(input);
            var sources = compiler.ToCode();
            Assert.IsTrue(compiler.Errors.Count == 0);
        }
    }
}
