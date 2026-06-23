package com.test.servlet;

import com.test.entity.Document;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.transaction.Transactional;
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
            // Check if entity class is enhanced
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

            out.println("=== Build-Time Enhancement Check ===");
            out.println("Has $$_hibernate_attributeInterceptor field: " + hasInterceptor);
            out.println("Implements PersistentAttributeInterceptable: " + implementsInterceptable);
            out.println("Enhancement active: " + (hasInterceptor && implementsInterceptable));
            out.println("STATUS: OK");

        } catch (Exception e) {
            out.println("ERROR: " + e.getMessage());
            e.printStackTrace(out);
        }
    }
}
