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

import Foundation

class FilterDetailsController : UIViewController {
    
    var filter: Filter!
    var isCustom: Bool!
    
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var deleteButtonHeightConstraint: NSLayoutConstraint!
    
    private let embedTableSegue = "embedTableSegue"
    
    private let theme: ThemeServiceProtocol = ServiceLocator.shared.getService()!
    private let configuration: ConfigurationService = ServiceLocator.shared.getService()!
    private let filtersService: FiltersServiceProtocol = ServiceLocator.shared.getService()!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        deleteButtonHeightConstraint.constant = isCustom ? 60 : 0
        updateTheme()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name( ConfigurationService.themeChangeNotification), object: nil, queue: OperationQueue.main) {[weak self] (notification) in
            self?.updateTheme()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == embedTableSegue {
            guard let tableController = segue.destination as? FilterDetailsTableCotroller else { return }
            tableController.filter = filter
        }
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        filtersService.deleteCustomFilter(filter)
        navigationController?.popViewController(animated: true)
    }
    
    private func updateTheme () {
        deleteButton.backgroundColor = theme.backgroundColor
    }
}

class FilterDetailsTableCotroller : UITableViewController {
    
    @IBOutlet var themableLabels: [ThemableLabel]!
    @IBOutlet var separators: [UIView]!
    
    @IBOutlet weak var enabledSwitch: UISwitch!
    @IBOutlet weak var descriptionLabel: ThemableLabel!
    @IBOutlet weak var versionLabel: ThemableLabel!
    @IBOutlet weak var updatedLabel: ThemableLabel!
    @IBOutlet weak var rulesCountLabel: ThemableLabel!
    @IBOutlet weak var websiteLabel: ThemableLabel!
    @IBOutlet weak var tagsView: FilterTagsView!
    
    var filter: Filter!
    
    private let theme: ThemeServiceProtocol = ServiceLocator.shared.getService()!
    private let filtersService: FiltersServiceProtocol = ServiceLocator.shared.getService()!
    
    
    // MARK: - constants
    
    // rows
    enum Row: Int {
        
    case enabled = 0,
        description,
        version,
        updated,
        rulesCount,
        website,
        tags
    }
    
    // MARK: view controller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        enabledSwitch.isOn = filter.enabled
        descriptionLabel.text = filter.desc
        versionLabel.text = filter.version
        updatedLabel.text = filter.updateDate?.formatedString()
        rulesCountLabel.text = "\(filter.rulesCount ?? 0)"
        
        tagsView.filter = filter
        
        updateTheme()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name( ConfigurationService.themeChangeNotification), object: nil, queue: OperationQueue.main) {[weak self] (notification) in
            self?.updateTheme()
        }
    }
    
    // MARK: - table view delegate and datasource methods
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let calculatedHeight = super.tableView(tableView, heightForRowAt: indexPath)
        
        guard let row = Row(rawValue: indexPath.row) else {
            assertionFailure("unexpected index")
            return calculatedHeight
        }
        
        switch row {
        case .enabled:
            return calculatedHeight
        
        case .description:
            return filter.desc == nil || filter.desc?.count == 0 ? 0 : calculatedHeight
            
        case .version:
            return filter.version == nil || filter.version?.count == 0 ? 0 : calculatedHeight
            
        case .updated:
            return filter.updateDate == nil ? 0 : calculatedHeight
            
        case .rulesCount:
            return filter.rulesCount == nil ? 0 : calculatedHeight
            
        case .website:
            return filter.homepage == nil || filter.homepage?.count == 0 ? 0 : calculatedHeight
            
        case .tags:
            let tagsCount = (filter.tags?.count ?? 0) + (filter.langs?.count ?? 0)
            return tagsCount == 0 ? 0 : calculatedHeight
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        theme.setupTableCell(cell)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = Row(rawValue: indexPath.row) else { return }
        if row == .website {
            if let url = URL(string: filter.homepage ?? "") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    @IBAction func toggleEnableSwitch(_ sender: UISwitch) {
        filtersService.setFilter(filter, enabled: sender.isOn)
    }
    
    // MARK: - private methods
    
    private func updateTheme() {
        
        view.backgroundColor = theme.backgroundColor
        theme.setupTable(tableView)
        theme.setupLabels(themableLabels)
        theme.setupSeparators(separators)
        
        if filter.homepage != nil {
            let homepage = NSAttributedString(string: filter.homepage!, attributes:
                [.foregroundColor: theme.grayTextColor,
                 .underlineStyle: NSUnderlineStyle.single.rawValue])
            websiteLabel.attributedText = homepage
        }
    }
}
