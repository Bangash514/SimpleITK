#!/usr/bin/env python
# =========================================================================
#
#  Copyright NumFOCUS
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0.txt
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
# =========================================================================


import os
import sys

import SimpleITK as sitk

if len(sys.argv) != 2:
    print("Usage: %s inputImage" % (sys.argv[0]))
    sys.exit(1)

inputImage = sitk.ReadImage(sys.argv[1])

if ("SITK_NOSHOW" not in os.environ):
    sitk.Show(inputImage)
