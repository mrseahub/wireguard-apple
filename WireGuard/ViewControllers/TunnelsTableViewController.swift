//
//  TunnelsTableViewController.swift
//  WireGuard
//
//  Created by Jeroen Leenarts on 23-05-18.
//  Copyright © 2018 Jason A. Donenfeld <Jason@zx2c4.com>. All rights reserved.
//

import UIKit

import CoreData
import BNRCoreDataStack
import NetworkExtension

protocol TunnelsTableViewControllerDelegate: class {
    func addProvider(tunnelsTableViewController: TunnelsTableViewController)
    func connect(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController)
    func disconnect(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController)
    func configure(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController)
    func delete(tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController)
    func status(for tunnel: Tunnel, tunnelsTableViewController: TunnelsTableViewController) -> NEVPNStatus
}

class TunnelsTableViewController: UITableViewController {
    weak var delegate: TunnelsTableViewControllerDelegate?

    var viewContext: NSManagedObjectContext!

    private lazy var fetchedResultsController: FetchedResultsController<Tunnel> = {
        let fetchRequest = NSFetchRequest<Tunnel>()
        fetchRequest.entity = Tunnel.entity()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        let frc = FetchedResultsController<Tunnel>(fetchRequest: fetchRequest,
                                                    managedObjectContext: viewContext)
        frc.setDelegate(self.frcDelegate)
        return frc
    }()

    public func updateStatus(for tunnelIdentifier: String) {
        viewContext.perform {
            let tunnel = try? Tunnel.findFirstInContext(self.viewContext, predicate: NSPredicate(format: "tunnelIdentifier == %@", tunnelIdentifier))
            if let tunnel = tunnel {
                if let indexPath = self.fetchedResultsController.indexPathForObject(tunnel!) {
                    self.tableView.reloadRows(at: [indexPath], with: UITableViewRowAnimation.none)
                }
            }
        }
    }

    private lazy var frcDelegate: TunnelFetchedResultsControllerDelegate = { // swiftlint:disable:this weak_delegate
        return TunnelFetchedResultsControllerDelegate(tableView: self.tableView)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Failed to fetch objects: \(error)")
        }

        // Get rid of seperator lines in table.
        tableView.tableFooterView = UIView(frame: CGRect.zero)
    }

    @IBAction func addProvider(_ sender: Any) {
        delegate?.addProvider(tunnelsTableViewController: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[0].objects.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: TunnelTableViewCell.self, for: indexPath)
        cell.delegate = self

        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let tunnel = section.objects[indexPath.row]

        cell.configure(tunnel: tunnel, status: delegate?.status(for: tunnel, tunnelsTableViewController: self) ?? .invalid)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let tunnel = section.objects[indexPath.row]

        delegate?.configure(tunnel: tunnel, tunnelsTableViewController: self)

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let sections = fetchedResultsController.sections else {
            fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
        }

        let section = sections[indexPath.section]
        let tunnel = section.objects[indexPath.row]

        delegate?.configure(tunnel: tunnel, tunnelsTableViewController: self)

    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {

            guard let sections = fetchedResultsController.sections else {
                fatalError("FetchedResultsController \(fetchedResultsController) should have sections, but found nil")
            }

            let section = sections[indexPath.section]
            let tunnel = section.objects[indexPath.row]

            delegate?.delete(tunnel: tunnel, tunnelsTableViewController: self)
        }
    }
}

extension TunnelsTableViewController: TunnelTableViewCellDelegate {
    func connect(tunnelIdentifier: String) {
        let tunnel = try? Tunnel.findFirstInContext(self.viewContext, predicate: NSPredicate(format: "tunnelIdentifier == %@", tunnelIdentifier))
        if let tunnel = tunnel {
            self.delegate?.connect(tunnel: tunnel!, tunnelsTableViewController: self)
        }
    }

    func disconnect(tunnelIdentifier: String) {
        let tunnel = try? Tunnel.findFirstInContext(self.viewContext, predicate: NSPredicate(format: "tunnelIdentifier == %@", tunnelIdentifier))
        if let tunnel = tunnel {
            self.delegate?.disconnect(tunnel: tunnel!, tunnelsTableViewController: self)
        }
    }

}

extension TunnelsTableViewController: Identifyable {}

class TunnelFetchedResultsControllerDelegate: NSObject, FetchedResultsControllerDelegate {

    private weak var tableView: UITableView?

    // MARK: - Lifecycle
    init(tableView: UITableView) {
        self.tableView = tableView
    }

    func fetchedResultsControllerDidPerformFetch(_ controller: FetchedResultsController<Tunnel>) {
        tableView?.reloadData()
    }

    func fetchedResultsControllerWillChangeContent(_ controller: FetchedResultsController<Tunnel>) {
        tableView?.beginUpdates()
    }

    func fetchedResultsControllerDidChangeContent(_ controller: FetchedResultsController<Tunnel>) {
        tableView?.endUpdates()
    }

    func fetchedResultsController(_ controller: FetchedResultsController<Tunnel>, didChangeObject change: FetchedResultsObjectChange<Tunnel>) {
        guard let tableView = tableView else { return }
        switch change {
        case let .insert(_, indexPath):
            tableView.insertRows(at: [indexPath], with: .automatic)

        case let .delete(_, indexPath):
            tableView.deleteRows(at: [indexPath], with: .automatic)

        case let .move(_, fromIndexPath, toIndexPath):
            tableView.moveRow(at: fromIndexPath, to: toIndexPath)

        case let .update(_, indexPath):
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }

    func fetchedResultsController(_ controller: FetchedResultsController<Tunnel>, didChangeSection change: FetchedResultsSectionChange<Tunnel>) {
        guard let tableView = tableView else { return }
        switch change {
        case let .insert(_, index):
            tableView.insertSections(IndexSet(integer: index), with: .automatic)

        case let .delete(_, index):
            tableView.deleteSections(IndexSet(integer: index), with: .automatic)
        }
    }
}

protocol TunnelTableViewCellDelegate: class {
    func connect(tunnelIdentifier: String)
    func disconnect(tunnelIdentifier: String)
}

class TunnelTableViewCell: UITableViewCell {

    @IBOutlet weak var tunnelTitleLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    weak var delegate: TunnelTableViewCellDelegate?
    private var tunnelIdentifier: String?

    let tunnelSwitch = UISwitch(frame: CGRect(x: 0, y: 0, width: 20, height: 20))

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        tunnelSwitch.addTarget(self, action: #selector(tunnelSwitchChanged(_:)), for: .valueChanged)
        self.accessoryView = tunnelSwitch
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        tunnelSwitch.addTarget(self, action: #selector(tunnelSwitchChanged(_:)), for: .valueChanged)
        accessoryView = tunnelSwitch
    }

    @IBAction func tunnelSwitchChanged(_ sender: Any) {
        tunnelSwitch.isUserInteractionEnabled = false
        guard let tunnelIdentifier = tunnelIdentifier else {
            return
        }

        if tunnelSwitch.isOn {
            delegate?.connect(tunnelIdentifier: tunnelIdentifier)
        } else {
            delegate?.disconnect(tunnelIdentifier: tunnelIdentifier)
        }
    }

    func configure(tunnel: Tunnel, status: NEVPNStatus) {
        self.tunnelTitleLabel?.text = tunnel.title
        tunnelIdentifier = tunnel.tunnelIdentifier
        switch status {
        case .connected:
            activityIndicator.stopAnimating()
            tunnelSwitch.isOn = true
            tunnelSwitch.isEnabled = true
            tunnelSwitch.onTintColor = UIColor.green
        case .connecting:
            activityIndicator.startAnimating()
            tunnelSwitch.isOn = true
            tunnelSwitch.isEnabled = false
            tunnelSwitch.onTintColor = UIColor.yellow
        case .disconnected:
            activityIndicator.stopAnimating()
            tunnelSwitch.isOn = false
            tunnelSwitch.isEnabled = true
            tunnelSwitch.onTintColor = UIColor.green
        case .disconnecting:
            activityIndicator.startAnimating()
            tunnelSwitch.isOn = false
            tunnelSwitch.isEnabled = true
            tunnelSwitch.onTintColor = UIColor.green
        case .invalid:
            activityIndicator.stopAnimating()
            tunnelSwitch.isEnabled = false
            tunnelSwitch.isUserInteractionEnabled = false
            tunnelSwitch.onTintColor = UIColor.gray
        case .reasserting:
            activityIndicator.startAnimating()
            tunnelSwitch.isEnabled = true
            tunnelSwitch.isUserInteractionEnabled = false
            tunnelSwitch.onTintColor = UIColor.yellow
        }
        tunnelSwitch.isUserInteractionEnabled = true
    }
}

extension TunnelTableViewCell: Identifyable {}
