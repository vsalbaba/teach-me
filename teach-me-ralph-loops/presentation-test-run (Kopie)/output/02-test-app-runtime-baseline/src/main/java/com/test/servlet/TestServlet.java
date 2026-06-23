package com.test.servlet;

import com.test.entity.Document;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;

@WebServlet("/test")
public class TestServlet extends HttpServlet {

    @PersistenceContext(unitName = "test-pu")
    private EntityManager em;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        resp.setContentType("text/plain");
        PrintWriter out = resp.getWriter();

        try {
            Class<?> docClass = Document.class;

            boolean hasInterceptor = false;
            try {
                docClass.getDeclaredField("$$_hibernate_attributeInterceptor");
                hasInterceptor = true;
            } catch (NoSuchFieldException e) {
                // not enhanced
            }

            boolean implementsInterceptable = false;
            for (Class<?> iface : docClass.getInterfaces()) {
                if (iface.getSimpleName().equals("PersistentAttributeInterceptable")) {
                    implementsInterceptable = true;
                    break;
                }
            }

            boolean implementsSelfDirtiness = false;
            for (Class<?> iface : docClass.getInterfaces()) {
                if (iface.getSimpleName().equals("SelfDirtinessTracker")) {
                    implementsSelfDirtiness = true;
                    break;
                }
            }

            boolean implementsManagedEntity = false;
            for (Class<?> iface : docClass.getInterfaces()) {
                if (iface.getSimpleName().equals("ManagedEntity")) {
                    implementsManagedEntity = true;
                    break;
                }
            }

            out.println("=== Runtime Enhancement Baseline Check ===");
            out.println("Has $$_hibernate_attributeInterceptor field: " + hasInterceptor);
            out.println("Implements PersistentAttributeInterceptable: " + implementsInterceptable);
            out.println("Implements SelfDirtinessTracker: " + implementsSelfDirtiness);
            out.println("Implements ManagedEntity: " + implementsManagedEntity);
            out.println("Enhancement active: " + (hasInterceptor && implementsInterceptable));

            if (hasInterceptor && implementsInterceptable) {
                out.println("Source: RUNTIME (class was not enhanced at build time)");
            } else {
                out.println("Source: NONE (no enhancement detected)");
            }
            out.println("STATUS: OK");

        } catch (Exception e) {
            out.println("ERROR: " + e.getMessage());
            e.printStackTrace(out);
        }
    }
}
