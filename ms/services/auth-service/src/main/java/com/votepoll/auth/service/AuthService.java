package com.votepoll.auth.service;

import com.votepoll.auth.model.Admin;
import com.votepoll.auth.repository.AdminRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
public class AuthService {
    private final AdminRepository adminRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(AdminRepository adminRepository, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.adminRepository = adminRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    public Optional<Admin> authenticate(String email, String password) {
        Optional<Admin> admin = adminRepository.findByEmailAndActiveTrue(email);
        if (admin.isEmpty()) {
            System.out.println("DEBUG: No active admin found for email: " + email);
            return Optional.empty();
        }
        boolean matches = passwordEncoder.matches(password, admin.get().getPasswordHash());
        if (!matches) {
            System.out.println("DEBUG: Password mismatch.");
            System.out.println("DEBUG: Input length: " + password.length());
            System.out.println("DEBUG: DB Hash: " + admin.get().getPasswordHash());
        }
        return admin.filter(a -> matches);
    }

    public String issueToken(Admin admin) {
        System.out.println("DEBUG: AuthService issueToken called for: " + admin.getEmail());
        return jwtService.generateToken(admin);
    }
}
