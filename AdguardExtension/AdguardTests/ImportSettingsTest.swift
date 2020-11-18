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

import XCTest

class ImportSettingsTest: XCTestCase {
    
    var filtersService = FiltersServiceMock()
    var antibanner = AntibannerMock()
    var networking = NetworkMock()
    var dnsFiltersService = DnsFiltersServiceMock()
    var dnsProviders = DnsProvidersServiceMock()
    var purchaseService = PurchaseServiceMock()
    var contentBlockerService = ContentBlockerServiceMock()
    var importService: ImportSettingsServiceProtocol!
    

    override func setUpWithError() throws {
        importService = ImportSettingsService(antibanner: antibanner, networking: networking, filtersService: filtersService, dnsFiltersService: dnsFiltersService, dnsProvidersService: dnsProviders, purchaseService: purchaseService, contentBlockerService: contentBlockerService)
        
        let group = Group(1)
        let filter = Filter(filterId: 2, groupId: 1)
        filter.enabled = false
        group.filters = [filter]
        filtersService.groups = [group]
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testEnableFilter() {
        var settings = Settings()
        settings.defaultCbFilters = [DefaultCBFilterSettings(id: 2, enable: true)]
        
        let expectation = XCTestExpectation()
        importService.applySettings(settings) { (settings) in
            XCTAssertEqual(settings.defaultCbFilters?.first?.status, .successful)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        for group  in filtersService.groups {
            for filter in group.filters {
                
                if filter.filterId == 2 {
                    XCTAssertTrue(filter.enabled)
                    return
                }
            }
        }
        XCTFail()
    }
    
    func testAddCustomFilter() {
        var settings = Settings()
        settings.customCbFilters = [CustomCBFilterSettings(name: "custom", url: "custom_url")]
        
        let customGroup = Group(FilterGroupId.custom)
        filtersService.groups = [customGroup]
        
        networking.response = URLResponse(url: URL(string: "custom_url")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        networking.returnString = "rules"
        
        let expectation = XCTestExpectation()
        importService.applySettings(settings) { (settings) in
            
            let filter = customGroup.filters.first
            XCTAssertNotNil(filter)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAddCustomDnsFilter() {
        var settings = Settings()
        settings.dnsFilters = [DnsFilterSettings(name: "custom_dns", url: "custom_dns_url")]
        
        dnsFiltersService.filters = []
        
        let expectation = XCTestExpectation()
        
        importService.applySettings(settings) { [unowned self] (settings) in
            
            let newFilter = self.dnsFiltersService.filters.first
            XCTAssertNotNil(newFilter)
            XCTAssertEqual(newFilter?.name, "custom_dns")
            XCTAssertEqual(newFilter?.subscriptionUrl, "custom_dns_url")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSelectDnsServer() {
        var settings = Settings()
        settings.dnsSetting = DnsFilteringSettings(name: DnsNameSetting(rawValue: "adguard-dns-family"), dnsProtocol: .doh)
        
        let provider = DnsProviderInfo(id: DnsProvidersService.adguardFamilyId, name: "ag family")
        provider.servers = [DnsServerInfo(dnsProtocol: .doh, serverId: "123", name: "ag family test", upstreams: [])]
        dnsProviders.allProviders = [provider]
        
        let expectation = XCTestExpectation()
        
        importService.applySettings(settings) { [unowned self] (settings) in
            
            let activeServer = dnsProviders.activeDnsServer
            XCTAssertNotNil(activeServer)
            XCTAssertEqual(activeServer?.serverId, "123")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testActivateLicense() {
        
        var settings = Settings()
        settings.license = "license"
        
        let expectation = XCTestExpectation()
        
        importService.applySettings(settings) { [unowned self] (settings) in
            
            XCTAssertTrue(purchaseService.activateLicesnseCalled)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAddUserRules() {
        var settings = Settings()
        settings.userRules = ["rule"]
        
        let expectation = XCTestExpectation()
        
        importService.applySettings(settings) { [unowned self] (settings) in
            
            let userRules = antibanner.rules[ASDF_USER_FILTER_ID as! NSNumber]
            XCTAssertEqual(userRules!.first!.ruleText, "rule")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAddallowRules() {
        var settings = Settings()
        settings.allowlistRules = ["rule"]
        
        let expectation = XCTestExpectation()
        
        importService.applySettings(settings) { [unowned self] (settings) in
            
            XCTAssertEqual(contentBlockerService.whitelistDomains.first, "rule")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAddDnsRule() {
        var settings = Settings()
        settings.dnsUserRules = ["rule"]
        
        let expectation = XCTestExpectation()
        
        importService.applySettings(settings) { [unowned self] (settings) in
            
            XCTAssertEqual(dnsFiltersService.userRules.first, "rule")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
