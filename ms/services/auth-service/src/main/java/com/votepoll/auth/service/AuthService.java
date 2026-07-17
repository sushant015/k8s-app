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
        return adminRepository.findByEmailAndActiveTrue(email)
                .filter(a -> passwordEncoder.matches(password, a.getPasswordHash()));
    }

    public String issueToken(Admin admin) {
        return jwtService.generateToken(admin);
    }
}
