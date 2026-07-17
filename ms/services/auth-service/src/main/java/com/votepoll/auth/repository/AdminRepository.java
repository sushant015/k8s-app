package com.votepoll.auth.repository;

import com.votepoll.auth.model.Admin;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.UUID;

public interface AdminRepository extends JpaRepository<Admin, UUID> {
    Optional<Admin> findByEmailAndActiveTrue(String email);
}
