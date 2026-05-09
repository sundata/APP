import Foundation
import BackgroundTasks

// MARK: - 后台定时抓取任务注册器
// 在 AppDelegate 或 App 初始化时调用 BackgroundFetchManager.shared.register()
class BackgroundFetchManager {
    static let shared = BackgroundFetchManager()
    
    // BGTask identifier（需在 Info.plist 的 BGTaskSchedulerPermittedIdentifiers 注册）
    static let fetchTaskIdentifier   = "com.newsnow.app.fetch"
    static let refreshTaskIdentifier = "com.newsnow.app.refresh"
    
    private init() {}
    
    // MARK: - 注册
    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.fetchTaskIdentifier,
            using: nil
        ) { task in
            self.handleFetch(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleProcessing(task: task as! BGProcessingTask)
        }
    }
    
    // MARK: - 调度下一次抓取
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.fetchTaskIdentifier)
        // 最早 15 分钟后执行
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BGAppRefresh 调度失败: \(error)")
        }
    }
    
    func scheduleProcessingRefresh() {
        let request = BGProcessingTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BGProcessing 调度失败: \(error)")
        }
    }
    
    // MARK: - 执行抓取
    private func handleFetch(task: BGAppRefreshTask) {
        // 调度下一次
        scheduleAppRefresh()
        
        let fetchTask = Task {
            await NewsService.shared.fetchNews()
            task.setTaskCompleted(success: true)
        }
        
        task.expirationHandler = {
            fetchTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    private func handleProcessing(task: BGProcessingTask) {
        scheduleProcessingRefresh()
        
        let processTask = Task {
            // 全分类刷新
            for category in NewsCategory.allCases {
                await NewsService.shared.fetchNews(category: category)
            }
            task.setTaskCompleted(success: true)
        }
        
        task.expirationHandler = {
            processTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
