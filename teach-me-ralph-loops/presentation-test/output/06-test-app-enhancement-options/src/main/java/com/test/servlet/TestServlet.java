package com.test.servlet;

import com.test.entity.Department;
import com.test.entity.Employee;
import jakarta.annotation.Resource;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.PersistenceUnit;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.transaction.UserTransaction;
import java.io.IOException;
import java.io.PrintWriter;

@WebServlet("/test")
public class TestServlet extends HttpServlet {

    @PersistenceUnit(unitName = "testPU")
    private EntityManagerFactory emf;

    @Resource
    private UserTransaction utx;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {
        resp.setContentType("text/plain");
        PrintWriter out = resp.getWriter();

        try {
            // -- Check 1: Is entity enhanced (ManagedTypeHelper) --
            boolean isManagedType = false;
            try {
                Class<?> helperClass = Class.forName("org.hibernate.engine.internal.ManagedTypeHelper");
                java.lang.reflect.Method method = helperClass.getMethod("isManagedType", Class.class);
                isManagedType = (Boolean) method.invoke(null, Employee.class);
            } catch (Exception e) {
                out.println("WARN: Could not check ManagedTypeHelper: " + e.getMessage());
            }
            out.println("BUILD_TIME_ENHANCED=" + isManagedType);

            // -- Check 2: Lazy loading support (PersistentAttributeInterceptable) --
            boolean isInterceptable = false;
            try {
                Class<?> interceptable = Class.forName(
                    "org.hibernate.engine.spi.PersistentAttributeInterceptable");
                isInterceptable = interceptable.isAssignableFrom(Employee.class);
            } catch (Exception e) {
                out.println("WARN: Could not check PersistentAttributeInterceptable: " + e.getMessage());
            }
            out.println("LAZY_LOADING_CAPABLE=" + isInterceptable);

            // -- Check 3: Dirty tracking support (SelfDirtinessTracker) --
            boolean isDirtyTracker = false;
            try {
                Class<?> tracker = Class.forName(
                    "org.hibernate.engine.spi.SelfDirtinessTracker");
                isDirtyTracker = tracker.isAssignableFrom(Employee.class);
            } catch (Exception e) {
                out.println("WARN: Could not check SelfDirtinessTracker: " + e.getMessage());
            }
            out.println("DIRTY_TRACKING_CAPABLE=" + isDirtyTracker);

            // -- Check 4: Department also enhanced --
            boolean deptManaged = false;
            try {
                Class<?> helperClass = Class.forName("org.hibernate.engine.internal.ManagedTypeHelper");
                java.lang.reflect.Method method = helperClass.getMethod("isManagedType", Class.class);
                deptManaged = (Boolean) method.invoke(null, Department.class);
            } catch (Exception e) {
                out.println("WARN: Could not check Department enhancement: " + e.getMessage());
            }
            out.println("DEPARTMENT_ENHANCED=" + deptManaged);

            // -- Check 5: @EnhancementInfo annotation --
            boolean hasEnhancementInfo = false;
            try {
                Class<?> annoClass = Class.forName("org.hibernate.bytecode.enhance.spi.EnhancementInfo");
                hasEnhancementInfo = Employee.class.isAnnotationPresent((Class) annoClass);
                if (hasEnhancementInfo) {
                    java.lang.annotation.Annotation anno = Employee.class.getAnnotation((Class) annoClass);
                    java.lang.reflect.Method versionMethod = annoClass.getMethod("version");
                    String version = (String) versionMethod.invoke(anno);
                    out.println("ENHANCEMENT_INFO_VERSION=" + version);
                }
            } catch (Exception e) {
                out.println("WARN: Could not check EnhancementInfo: " + e.getMessage());
            }
            out.println("HAS_ENHANCEMENT_INFO=" + hasEnhancementInfo);

            // -- Check 6: Persistence test with both entities --
            utx.begin();
            EntityManager em = emf.createEntityManager();

            Department dept = new Department();
            dept.setId(1);
            dept.setName("Engineering");
            em.persist(dept);

            Employee emp = new Employee();
            emp.setId(1);
            emp.setName("Test Employee");
            emp.setAddress("Test Address");
            emp.setBiography("A long biography text for lazy loading test");
            emp.setDepartment(dept);
            em.persist(emp);

            em.flush();
            utx.commit();

            // Read back in new transaction
            utx.begin();
            em = emf.createEntityManager();
            Employee loaded = em.find(Employee.class, 1);
            out.println("EMPLOYEE_LOADED=" + (loaded != null));
            out.println("EMPLOYEE_NAME=" + (loaded != null ? loaded.getName() : "null"));

            if (loaded != null && loaded.getDepartment() != null) {
                out.println("DEPARTMENT_NAME=" + loaded.getDepartment().getName());
            } else {
                out.println("DEPARTMENT_NAME=null");
            }

            Department loadedDept = em.find(Department.class, 1);
            int employeeCount = loadedDept != null ? loadedDept.getEmployees().size() : 0;
            out.println("DEPT_EMPLOYEE_COUNT=" + employeeCount);

            utx.commit();

            out.println("PERSISTENCE_OK=true");

        } catch (Exception e) {
            out.println("PERSISTENCE_OK=false");
            out.println("ERROR=" + e.getMessage());
            e.printStackTrace(out);
        }
    }
}
