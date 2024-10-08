/*
 * Copyright 2023, The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {Input} from '@angular/core';
import {VariableHeightScrollStrategy} from './variable_height_scroll_strategy';

export abstract class VariableHeightScrollDirective<T extends object> {
  abstract scrollStrategy: VariableHeightScrollStrategy;

  @Input()
  set scrollItems(items: T[]) {
    if (this.scrollItems !== items) {
      this.scrollStrategy.updateItems(items);
    }
  }
}
