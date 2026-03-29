/*
 * Partie 9 — cgroup v2 : isoler un processus fils
 *
 * Compile : gcc -O0 -o cg_demo cg_demo.c
 * Run     : sudo ./cg_demo
 *
 * Ce programme démontre la mécanique qu'utilise runc/crun
 * pour chaque container : fork() + écriture dans cgroup.procs
 * avant exec() de l'application.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>

#define CG_ROOT "/sys/fs/cgroup"
#define CG_NAME "demo_c"
#define CG_PATH CG_ROOT "/" CG_NAME

#define MEM_LIMIT  "67108864"    /* 64 MiB */
#define CPU_QUOTA  "250000 1000000"  /* 25% d'un CPU */

/* Écrire une valeur dans un fichier du cgroup */
static int cg_write(const char *filename, const char *value)
{
    char path[512];
    snprintf(path, sizeof(path), CG_PATH "/%s", filename);

    int fd = open(path, O_WRONLY | O_TRUNC);
    if (fd < 0) {
        fprintf(stderr, "open(%s): %s\n", path, strerror(errno));
        return -1;
    }
    ssize_t n = write(fd, value, strlen(value));
    close(fd);
    return (n < 0) ? -1 : 0;
}

/* Lire et afficher le contenu d'un fichier du cgroup */
static void cg_show(const char *filename)
{
    char path[512];
    snprintf(path, sizeof(path), CG_PATH "/%s", filename);

    FILE *f = fopen(path, "r");
    if (!f) { fprintf(stderr, "fopen(%s): %s\n", path, strerror(errno)); return; }

    char buf[256] = {0};
    fgets(buf, sizeof(buf), f);
    fclose(f);

    /* supprimer le '\n' final */
    size_t len = strlen(buf);
    if (len > 0 && buf[len-1] == '\n') buf[len-1] = '\0';

    printf("   %-20s = %s\n", filename, buf);
}

int main(void)
{
    if (geteuid() != 0) {
        fprintf(stderr, "Ce programme doit être exécuté en root.\n");
        return 1;
    }

    printf("=== cg_demo : isolation d'un processus fils ===\n\n");

    /* 1. Activer les contrôleurs dans le cgroup racine */
    printf("1. Activation des contrôleurs mémoire + CPU\n");
    {
        int fd = open(CG_ROOT "/cgroup.subtree_control", O_WRONLY);
        if (fd >= 0) { write(fd, "+memory +cpu", 12); close(fd); }
    }

    /* 2. Créer le cgroup */
    printf("2. Création du cgroup : %s\n", CG_PATH);
    if (mkdir(CG_PATH, 0755) < 0 && errno != EEXIST) {
        perror("mkdir"); return 1;
    }

    /* 3. Appliquer les limites */
    printf("3. Application des limites :\n");
    cg_write("memory.max", MEM_LIMIT);
    cg_write("cpu.max",    CPU_QUOTA);
    cg_show("memory.max");
    cg_show("cpu.max");

    /* 4. Fork : le fils rejoint le cgroup avant de travailler */
    printf("\n4. fork() — le fils rejoindra le cgroup\n");
    pid_t pid = fork();

    if (pid < 0) {
        perror("fork"); return 1;
    }

    if (pid == 0) {
        /* ---- processus FILS ---- */
        char pid_str[32];
        snprintf(pid_str, sizeof(pid_str), "%d", getpid());

        /* Rejoindre le cgroup AVANT de faire quoi que ce soit */
        if (cg_write("cgroup.procs", pid_str) < 0) {
            fprintf(stderr, "Impossible de rejoindre le cgroup\n");
            _exit(1);
        }

        printf("   [fils PID %d] dans le cgroup %s\n", getpid(), CG_NAME);
        printf("   [fils] mémoire max : 64 MiB, CPU : 25%%\n");

        /* Boucle CPU pour rendre le throttling observable */
        printf("   [fils] boucle CPU 2 milliards d'itérations...\n");
        for (volatile long i = 0; i < 2000000000L; i++)
            ;

        printf("   [fils] terminé\n");
        _exit(0);
    }

    /* ---- processus PÈRE ---- */
    printf("   [père PID %d] attend la fin du fils...\n", getpid());
    printf("   → observer avec : top -p %d  (throttle à ~25%% CPU attendu)\n\n", pid);

    int status;
    waitpid(pid, &status, 0);

    if (WIFSIGNALED(status))
        printf("   [père] fils tué par signal %d (OOM kill si SIGKILL)\n", WTERMSIG(status));
    else
        printf("   [père] fils terminé normalement (code %d)\n", WEXITSTATUS(status));

    /* 5. Nettoyage */
    printf("\n5. Nettoyage du cgroup\n");
    if (rmdir(CG_PATH) == 0)
        printf("   ✓ %s supprimé\n", CG_PATH);
    else
        fprintf(stderr, "   rmdir: %s\n", strerror(errno));

    printf("\n=== Démo terminée ===\n");
    return 0;
}
