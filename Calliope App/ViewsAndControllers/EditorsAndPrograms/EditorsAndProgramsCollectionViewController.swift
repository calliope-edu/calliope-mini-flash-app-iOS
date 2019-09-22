//
//  EditorsAndProgramsCollectionViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 02.06.19.
//

import UIKit
import DeepDiff

class EditorsAndProgramsCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, ProgramCellDelegate {

	private let reuseIdentifierWebEditor = "webEditorCell"
	private let reuseIdentifierOfflineEditor = "localEditorCell"
	private let reuseIdentifierPlayground = "playgroundCell"
	private let reuseIdentifierProgram = "editableProgramCell"

	private let reuseIdentifierHeader = "headerWithButton"

	private var makeCodeCell: EditorCollectionViewCell?
	private var robertaCell: EditorCollectionViewCell?
	private var playgroundCell: EditorCollectionViewCell?
	private var offlineEditorCell: EditorCollectionViewCell?

	private lazy var activatedEditors: [SettingsKey] = {
		var keys: [SettingsKey] = []
		let settings = UserDefaults.standard
		if settings.bool(forKey: SettingsKey.localEditorOn.rawValue) {
			keys.append(.localEditorOn)
		}
		if settings.bool(forKey: SettingsKey.robertaOn.rawValue) {
			keys.append(.robertaOn)
		}
		if settings.bool(forKey: SettingsKey.makeCodeOn.rawValue) {
			keys.append(.makeCodeOn)
		}
		if settings.bool(forKey: SettingsKey.playgroundsOn.rawValue) {
			keys.append(.playgroundsOn)
		}
		return keys
	}()

	private lazy var hexFiles: [HexFile] = { () -> [HexFile] in
		do { return try HexFileManager.stored() }
		catch { fatalError("could not load files \(error)") }
	}()

	private var subscription: NSObjectProtocol!

    override func viewDidLoad() {
        super.viewDidLoad()

		(collectionViewLayout as! UICollectionViewFlowLayout).estimatedItemSize = UICollectionViewFlowLayout.automaticSize
		subscription = NotificationCenter.default.addObserver(
			forName: NotificationConstants.hexFileChanged, object: nil, queue: nil,
			using: { [weak self] (_) in
				self?.animateFileChange()
		})


    }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.navigationController?.setNavigationBarHidden(true, animated: animated)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
        let cells = self.collectionView.visibleCells.compactMap { $0 as? ProgramCollectionViewCell }
        for cell in cells {
            self.recalculateProgramCellSize(size, cell)
        }
        
		coordinator.animate(alongsideTransition: {_ in
			self.collectionView.performBatchUpdates(nil, completion: nil)
		}, completion: nil)
	}

	private func recalculateProgramCellSize(_ size: CGSize, _ cell: ProgramCollectionViewCell) {
		let width = size.width - spacing
		let maxNumCells = ceil(width / programWidthThreshold)
		let calculatedWidth = width / maxNumCells - spacing
		cell.widthConstraint.constant = calculatedWidth
	}

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		if section == 0 {
			return activatedEditors.count
		} else {
			return hexFiles.count
		}
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell: UICollectionViewCell
		if indexPath.first == 0 {
            cell = createEditorCell(indexPath, collectionView)
		} else {
            cell = createProgramCell(collectionView, indexPath)
		}
		
        return cell
    }
    
    private func createProgramCell(_ collectionView: UICollectionView, _ indexPath: IndexPath) -> UICollectionViewCell {
        let cell: ProgramCollectionViewCell
        
        //TODO: Configure the cell
        cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath) as! ProgramCollectionViewCell
        
        recalculateProgramCellSize(collectionView.frame.size, cell)
        
        cell.program = hexFiles[indexPath.row]
        cell.delegate = self
        
        return cell
    }
    
    private func createEditorCell(_ indexPath: IndexPath, _ collectionView: UICollectionView) -> UICollectionViewCell {
        guard indexPath.row < activatedEditors.count else {
            fatalError("The program editor collection view features only \(activatedEditors.count) editors. numberOfItemsInSection must be set to that value.")
        }
        
        let cell: UICollectionViewCell
        let editorKey = activatedEditors[indexPath.row]
        
        switch editorKey {
        case .robertaOn:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierWebEditor, for: indexPath)
            robertaCell = cell as? EditorCollectionViewCell
            robertaCell?.button.setTitle("Roberta", for: UIControl.State.normal)
        case .makeCodeOn:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierWebEditor, for: indexPath)
            makeCodeCell = cell as? EditorCollectionViewCell
            makeCodeCell?.button.setTitle("MakeCode", for: UIControl.State.normal)
        case .playgroundsOn:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierPlayground, for: indexPath)
            playgroundCell = cell as? EditorCollectionViewCell
        case .localEditorOn:
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierOfflineEditor, for: indexPath)
            offlineEditorCell = cell as? EditorCollectionViewCell
        default:
            fatalError("invalid key found in active editors array")
        }
        
        (cell as! EditorCollectionViewCell).heightConstraint.constant = editorButtonSize
        (cell as! EditorCollectionViewCell).widthConstraint.constant = editorButtonSize
        return cell
    }

	override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		if kind == UICollectionView.elementKindSectionHeader {
			let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: reuseIdentifierHeader, for: indexPath) as! EditorAndProgramsSectionHeader
            if indexPath.section == 0 {
                view.titleText = "Editors for creating great programs"
                view.buttonHidden = true
            } else {
                view.titleText = "The programs that you already made"
                view.buttonHidden = false
            }
			return view
		} else {
			fatalError("The collection view only has headers, not \(kind)s")
		}
	}

	private func animateFileChange() {
		let oldItems = hexFiles
		let newItems = (try? HexFileManager.stored()) ?? []
		let changes = diff(old: oldItems, new: newItems)
		collectionView.reload(changes: changes, section: 1, updateData: {
			self.hexFiles = newItems
		})
	}

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    // menu

	override var canBecomeFirstResponder: Bool {
		return true
	}

	override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
		return indexPath.section == 1 && action == #selector(delete(_:))
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
		if action == #selector(delete(_:)) {
			guard let cell = self.collectionView.cellForItem(at: indexPath) as? ProgramCollectionViewCell else { fatalError("delete called not on program cell") }
			deleteProgram(of: cell)
		}
    }

	//dummy method for having some selector
	@objc func deleteSelectedProgram(sender: Any) {}

	// MARK: UICollectionViewDelegateFlowLayout

	let editorButtonSize: CGFloat = 180
	let programWidthThreshold: CGFloat = 500
	let defaultProgramHeight: CGFloat = 100
	let spacing: CGFloat = 10

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
		if section == 0 {
			let width = collectionView.frame.size.width
			let maxItems = width / (editorButtonSize + spacing)
			let numEditors = CGFloat(activatedEditors.count)
			if maxItems <= 2 {
				// flowlayout centers single cells
				return UIEdgeInsets.zero
			} else if maxItems < numEditors {
				let remainingSpace = width - 2 * editorButtonSize - spacing
				return UIEdgeInsets(top: 0, left: remainingSpace / 2, bottom: 0, right: remainingSpace / 2)
			} else {
				let remainingSpace = width - numEditors * editorButtonSize - (numEditors - 1) * spacing
				return UIEdgeInsets(top: 0, left: remainingSpace / 2, bottom: 0, right: remainingSpace / 2)
			}
		} else {
			return UIEdgeInsets(top: 0, left: spacing, bottom: 0, right: spacing)
		}
	}

	// MARK: - Navigation

	// In a storyboard-based application, you will often want to do a little preparation before navigation
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if sender as? UIButton == makeCodeCell?.button {
			(segue.destination as? EditorViewController)?.editor = MakeCode()
		} else if sender as? UIButton == robertaCell?.button {
			(segue.destination as? EditorViewController)?.editor = RobertaEditor()
		}
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.
	}

	// MARK: ProgramCellDelegate

	func share(cell: ProgramCollectionViewCell) {
		let program = cell.program!
		let activityItems = [program, program.name, program.descriptionText, program.url] as [Any]

		let activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
		activityViewController.modalTransitionStyle = UIModalTransitionStyle.coverVertical

		activityViewController.popoverPresentationController?.sourceRect = cell.frame
		activityViewController.popoverPresentationController?.sourceView = self.view

		self.present(activityViewController, animated: true, completion: nil)
	}

	func renameFailed(_ cell: ProgramCollectionViewCell, to newName: String) {
		let alertViewController = UIAlertController(title: "Could not rename \(cell.program.name)", message: "The name \(newName) could not be given to \(cell.program.name). The name for a program must be unique and not empty.", preferredStyle: .alert)
		alertViewController.addAction(UIAlertAction(title: "OK", style: .default)
		{ _ in self.dismiss(animated: true, completion: nil) })

		alertViewController.popoverPresentationController?.sourceView = cell
		alertViewController.popoverPresentationController?.sourceRect = cell.name.frame

		self.present(alertViewController, animated: true, completion: nil)
	}

	func programCellSizeDidChange(_ cell: ProgramCollectionViewCell) {
		collectionView.performBatchUpdates({}, completion: nil)
	}

	func uploadProgram(of cell: ProgramCollectionViewCell) {
		let alert = UIAlertController(title: "Upload?", message: "Do you want to upload \(cell.program.name) to your calliope?", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Upload", style: .default) { _ in
			let uploader = FirmwareUpload()
			self.present(uploader.alertView, animated: true) {
				uploader.upload(file: cell.program) {
					self.dismiss(animated: true, completion: nil)
				}
			}
		})
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		self.present(alert, animated: true)
	}

	func deleteProgram(of cell: ProgramCollectionViewCell) {
		let alert = UIAlertController(title: "Delete?", message: "Do you want to delete \(cell.program.name)?", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
			do {
				try HexFileManager.delete(file: cell.program)
				self.animateFileChange()
			} catch {
				let alert = UIAlertController(title: "Delete failed", message: "Could not delete \(cell.program.name)\n\(error.localizedDescription)", preferredStyle: .alert)
				alert.addAction(UIAlertAction(title: "OK", style: .default))
				self.present(alert, animated: true)
			}
		})
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		self.present(alert, animated: true)
	}

	deinit {
		NotificationCenter.default.removeObserver(subscription!)
	}
}
