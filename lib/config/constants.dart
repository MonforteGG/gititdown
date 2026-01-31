import 'package:flutter/material.dart';

class AppConstants {
  // GitHub API
  static const String githubApiBaseUrl = 'https://api.github.com';
  static const String githubRawBaseUrl = 'https://raw.githubusercontent.com';
  
  // API Headers
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/vnd.github.v3+json',
  };
  
  // Secure Storage Keys
  static const String storageKeyPat = 'github_pat';
  static const String storageKeyUsername = 'github_username';
  static const String storageKeyRepo = 'github_repo';
  
  // UI Constants
  static const double maxContentWidth = 800.0;
  static const Duration snackBarDuration = Duration(seconds: 3);
  
  // File Extensions
  static const String markdownExtension = '.md';
  
  // Default Values
  static const String defaultCommitMessage = 'Update via GitItDown';
  static const String defaultCreateMessage = 'Create via GitItDown';
  static const String defaultDeleteMessage = 'Delete via GitItDown';
  
  // GitHub Token URL
  static const String githubTokenUrl = 
      'https://github.com/settings/tokens/new?description=GitItDown+App&scopes=repo';
}
