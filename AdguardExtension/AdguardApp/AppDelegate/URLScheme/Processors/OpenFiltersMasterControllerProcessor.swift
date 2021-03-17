
/**
    This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
    Copyright © Adguard Software Limited. All rights reserved.

    Adguard for iOS is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Adguard for iOS is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
 */

struct OpenFiltersMasterControllerProcessor: IURLSchemeParametersProcessor {
    
    private let executor: IURLSchemeExecutor
    
    init(executor: IURLSchemeExecutor) {
        self.executor = executor
    }
    
    func process(parameters: [String : Any]) -> Bool {
        guard let showLaunchScreen = parameters["showLaunchScreen"] as? Bool else { return false }
        guard let url = (parameters["location"] as? String)?.removingPercentEncoding, !url.isEmpty else { return false }
        guard let title = (parameters["title"] as? String)?.removingPercentEncoding, !title.isEmpty else { return false}
        
        return executor.openFiltersMasterController(showLaunchScreen: showLaunchScreen, url: url, title: title)
    }
}
