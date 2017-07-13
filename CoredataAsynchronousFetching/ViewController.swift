//
//  ViewController.swift
//  CoredataAsynchronousFetching
//
//  Created by Abhishek Bedi on 7/13/17.
//  Copyright © 2017 abhishekbedi. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    
    // IBOutlets
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    let kMaxEntriesCount = 10000
    var totalRecords:Int = 0
    
    //MARK:-  View Controller Life Cycle Methods -
    override func viewDidLoad() {
        super.viewDidLoad()
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 5)
    }
    
    //MARK:- IBActions -
    @IBAction func insertButtonAction() {
        statusLabel.text = "Inserting \n..."
        insertRecords()
    }
    
    @IBAction func fetchButtonAction() {
        progressView.progress = 0
        statusLabel.text = "Fetching \n..."
        
        fetchAndUpdateProgressBar()
    }
    
    @IBAction func deleteButtonAction() {
        deleteRecords()
        statusLabel.text = "Delete \n👍"
    }
        
}

extension ViewController {
    
    func deleteRecords() {
        let fetch: NSFetchRequest<Student> = Student.fetchRequest()
        fetch.resultType = .countResultType
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetch as! NSFetchRequest<NSFetchRequestResult>)
        
        do {
            try self.appDelegate.persistentContainer.newBackgroundContext().execute(deleteRequest)
        } catch {
            print ("There was an error")
        }
    }
    
    func insertRecords() {
        self.appDelegate.persistentContainer.performBackgroundTask({ context in
            for _ in 1...self.kMaxEntriesCount {
                if let student = NSEntityDescription.insertNewObject(forEntityName: "Student", into: context) as? Student {
                    student.firstName = "New Firstname"
                    student.lastName = "New lastname"
                }
            }
            try? context.save()
            
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else {
                    print("Self is nil ")
                    return
                }
                strongSelf.statusLabel.text = "Inserted \n \(String(describing: strongSelf.kMaxEntriesCount)) records \n 👍"
            }
        })
    }
    
    private func fetchTotalRecordsCount() -> Int {
        let fetch: NSFetchRequest<Student> = Student.fetchRequest()
        let backgroundContext = self.appDelegate.persistentContainer.newBackgroundContext()
        var count = 0
        backgroundContext.performAndWait {
            do {
                count = try self.appDelegate.persistentContainer.newBackgroundContext().count(for: fetch)
            }
            catch let error {
                print("Fethcing in background failed with error: \(error)")
            }
        }
        return count
    }
    
    
    func fetchAndUpdateProgressBar() {
        
        do {
            // Fetch Total Records Count
            totalRecords = fetchTotalRecordsCount()
            print("\n\n *** Total Records: \(totalRecords) *** \n\n")
            guard totalRecords != 0 else {
                self.statusLabel.text = "Fetched \n \(self.totalRecords) records \n 😎"
                return
            }
            // Creates a new `Progress` object
            let progress = Progress(totalUnitCount: 1)
            
            // Sets the new progess as default one in the current thread
            progress.becomeCurrent(withPendingUnitCount: 1)
            
            let fetch: NSFetchRequest<Student> = Student.fetchRequest()
            let asynchronousFetchRequest = NSAsynchronousFetchRequest(fetchRequest: fetch, completionBlock: nil)
            
            // Keeps a reference of `NSPersistentStoreAsynchronousResult` returned by `execute`
            let fetchResult = try self.appDelegate.persistentContainer.newBackgroundContext().execute(asynchronousFetchRequest) as? NSPersistentStoreAsynchronousResult
            
            // Resigns the current progress
            progress.resignCurrent()
            
            // Adds observer
            fetchResult?.progress?.addObserver(self, forKeyPath: #keyPath(Progress.completedUnitCount), options: .new, context: nil)
            
        } catch let error {
            print("NSAsynchronousFetchRequest error: \(error)")
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == #keyPath(Progress.completedUnitCount),
            // Reads new value
            let newValue = change?[.newKey] as? Int {
            let fNewValue = Float(newValue)
            let fTotalRecords = Float(totalRecords)
            let progress = fNewValue / fTotalRecords
            
            print("\(newValue) / \(totalRecords) = \(progress)")
            
            let workItem = DispatchWorkItem(block: { [weak self] in
                self?.progressView.progress = progress
                if progress == 1.0 {
                    self?.statusLabel.text = "Fetched \n \(self!.totalRecords) records \n 😎"
                }
            })
            
            DispatchQueue.main.async(execute: workItem)
        }
    }
}
