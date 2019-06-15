//
//  EditorsAndProgramsCollectionViewController.swift
//  Calliope
//
//  Created by Tassilo Karge on 02.06.19.
//

import UIKit

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

	private lazy var hexFiles = { () -> [HexFile] in
		do {
			return try HexFileManager.stored()
		}
		catch {
			LOG(error)
			fatalError("could not load files")
		}
	}()

    override func viewDidLoad() {
        super.viewDidLoad()
		(collectionViewLayout as! UICollectionViewFlowLayout).estimatedItemSize = UICollectionViewFlowLayout.automaticSize
    }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.navigationController?.setNavigationBarHidden(true, animated: animated)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		let cells = collectionView.visibleCells.filter { ($0 as? ProgramCollectionViewCell) != nil } as! [ProgramCollectionViewCell]
		for cell in cells {
			self.recalculateProgramCellSize(size, cell)
		}
		coordinator.animate(alongsideTransition: {_ in
			for cell in cells {
				cell.changeTextExclusion()
			}
			self.collectionView.performBatchUpdates({}, completion: nil)
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
			return 4
		} else {
			return hexFiles.count
		}
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell: UICollectionViewCell
		if indexPath.first == 0 {
			switch indexPath.row {
			case 0:
				cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierWebEditor, for: indexPath)
				robertaCell = cell as? EditorCollectionViewCell
				robertaCell?.button.setTitle("Roberta", for: UIControl.State.normal)
			case 1:
				cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierWebEditor, for: indexPath)
					makeCodeCell = cell as? EditorCollectionViewCell
					makeCodeCell?.button.setTitle("MakeCode", for: UIControl.State.normal)
			case 2:
				cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierPlayground, for: indexPath)
				playgroundCell = cell as? EditorCollectionViewCell
			case 3:
				cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierOfflineEditor, for: indexPath)
				offlineEditorCell = cell as? EditorCollectionViewCell
			default:
				fatalError("The program editor collection view features only 4 editors. numberOfItemsInSection must be set to 4.")
			}

			(cell as! EditorCollectionViewCell).heightConstraint.constant = editorButtonSize
			(cell as! EditorCollectionViewCell).widthConstraint.constant = editorButtonSize
		} else {
			//TODO: Configure the cell
			cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifierProgram, for: indexPath)

			recalculateProgramCellSize(collectionView.frame.size, cell as! ProgramCollectionViewCell)
			(cell as! ProgramCollectionViewCell).changeTextExclusion()

			(cell as! ProgramCollectionViewCell).program = hexFiles[indexPath.row]
			(cell as! ProgramCollectionViewCell).delegate = self
		}
    
        return cell
    }

	override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		if kind == UICollectionView.elementKindSectionHeader {
			let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: reuseIdentifierHeader, for: indexPath)
			//TODO: Configure the view
			return view
		} else {
			fatalError("The collection view only has headers, not \(kind)s")
		}
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

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

	// MARK: UICollectionViewDelegateFlowLayout

	let editorButtonSize: CGFloat = 180
	let programWidthThreshold: CGFloat = 650
	let defaultProgramHeight: CGFloat = 100
	let spacing: CGFloat = 10

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
		if section == 0 {
			let width = collectionView.frame.size.width
			let maxItems = width / (editorButtonSize + spacing)
			if maxItems < 2 {
				return UIEdgeInsets.zero
			} else if maxItems < 4 {
				let remainingSpace = width - 2 * editorButtonSize - spacing
				return UIEdgeInsets(top: 0, left: remainingSpace / 2, bottom: 0, right: remainingSpace / 2)
			} else {
				let remainingSpace = width - 4 * editorButtonSize - 3 * spacing
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
			(segue.destination as? EditorViewController)?.editor = MicrobitEditor()
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
		//TODO upload
	}
}
