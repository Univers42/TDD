#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#include <stdarg.h>
#include <string.h>
#include <pthread.h>

// Define a maximum string length for random strings
#define MAX_STRING_LENGTH 20

typedef struct s_input {
    void *(*one_input)(void *input);
    void *(*two_input)(void *input1, void *input2);
    void *(*three_input)(void *input1, void *input2, void *input3);
    void *(*four_input)(void *input1, void *input2, void *input3, void *input4);
} t_input;

typedef struct s_function {
    char *name;
    void *function;
    char *description;
    int num_parameters;
    char **parameter_types;
} t_function;

typedef struct s_test {
    t_function *function1;
    t_function *function2;
    t_input *input;
    char *return_type;
    int num_tests;
} t_test;

/**
 * Get high precision time in nanoseconds.
 * @returns {double} The current time in seconds with nanosecond precision.
 */
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

/**
 * Compare outputs of two results.
 * @param {void*} result1 - The first result to compare.
 * @param {void*} result2 - The second result to compare.
 * @param {char*} type - The type of the results ("int", "double", "string").
 * @returns {int} 1 if the results are equal, 0 otherwise.
 */
int compare_outputs(void *result1, void *result2, char *type) {
    if (result1 == NULL || result2 == NULL) {
        return 0;
    }
    if (strcmp(type, "int") == 0) {
        return *(int *)result1 == *(int *)result2;
    } else if (strcmp(type, "double") == 0) {
        return *(double *)result1 == *(double *)result2;
    } else if (strcmp(type, "string") == 0) {
        return strcmp((char *)result1, (char *)result2) == 0;
    }
    return 0;
}

/**
 * Generate a random string of a given length.
 * @param {int} length - The length of the random string.
 * @returns {char*} The generated random string.
 */
char *generate_random_string(int length) {
    char *rand_str = malloc(length + 1);
    if (!rand_str) {
        perror("Failed to allocate memory for random string");
        exit(EXIT_FAILURE);
    }
    for (int i = 0; i < length; i++) {
        rand_str[i] = 'A' + (rand() % 26);
    }
    rand_str[length] = '\0';
    return rand_str;
}

/**
 * Generate random test cases based on parameter types.
 * @param {void**} args - The array to store generated arguments.
 * @param {char**} types - The array of parameter types.
 * @param {int} num_args - The number of arguments to generate.
 */
void generate_random_test_case(void **args, char **types, int num_args) {
    for (int i = 0; i < num_args; i++) {
        if (strcmp(types[i], "int") == 0) {
            int *rand_int = malloc(sizeof(int));
            if (!rand_int) {
                perror("Failed to allocate memory for random int");
                exit(EXIT_FAILURE);
            }
            *rand_int = rand() % 1000000;
            args[i] = rand_int;
        } else if (strcmp(types[i], "double") == 0) {
            double *rand_double = malloc(sizeof(double));
            if (!rand_double) {
                perror("Failed to allocate memory for random double");
                exit(EXIT_FAILURE);
            }
            *rand_double = (double)(rand() % 1000000) / 100.0;
            args[i] = rand_double;
        } else if (strcmp(types[i], "string") == 0) {
            args[i] = generate_random_string(rand() % MAX_STRING_LENGTH);
        }
    }
}

/**
 * Call the appropriate function based on the number of parameters.
 * @param {t_function*} func - The function to call.
 * @param {void**} args - The arguments to pass to the function.
 * @returns {void*} The result of the function call.
 */
void *call_function(t_function *func, void **args) {
    void *result = NULL;
    switch (func->num_parameters) {
        case 1:
            result = ((void *(*)(void *))func->function)(args[0]);
            break;
        case 2:
            result = ((void *(*)(void *, void *))func->function)(args[0], args[1]);
            break;
        case 3:
            result = ((void *(*)(void *, void *, void *))func->function)(args[0], args[1], args[2]);
            break;
        case 4:
            result = ((void *(*)(void *, void *, void *, void *))func->function)(args[0], args[1], args[2], args[3]);
            break;
    }
    return result;
}

// Structure to pass data to the thread
typedef struct {
    t_test *test;
    int start;
    int end;
    int pass_count;
    int func1_better;
    int func2_better;
} thread_data;

/**
 * Thread function to execute the tests.
 * @param {void*} arg - The thread data.
 * @returns {void*} NULL.
 */
void *test_functions_thread(void *arg) {
    thread_data *data = (thread_data *)arg;
    int inner_repeats = 1000;

    for (int i = data->start; i < data->end; i++) {
        void *args[4] = {NULL, NULL, NULL, NULL};
        generate_random_test_case(args, data->test->function1->parameter_types, data->test->function1->num_parameters);

        double start, end, time1, time2;
        void *result1 = NULL;
        void *result2 = NULL;

        // Measure first function
        start = get_time();
        for (int r = 0; r < inner_repeats; r++) {
            if (result1) free(result1);
            result1 = call_function(data->test->function1, args);
        }
        end = get_time();
        time1 = (end - start) / inner_repeats;

        // Measure second function
        start = get_time();
        for (int r = 0; r < inner_repeats; r++) {
            if (result2) free(result2);
            result2 = call_function(data->test->function2, args);
        }
        end = get_time();
        time2 = (end - start) / inner_repeats;

        // Compare outputs
        int same_output = compare_outputs(result1, result2, data->test->return_type);
        if (same_output) {
            data->pass_count++;
            if (time1 < time2) {
                data->func1_better++;
            } else if (time2 < time1) {
                data->func2_better++;
            }
        }

        // Free test case arguments
        for (int j = 0; j < data->test->function1->num_parameters; j++) {
            free(args[j]);
        }

        // Free results
        free(result1);
        free(result2);
    }

    pthread_exit(NULL);
}

/**
 * Benchmark and compare behavior with multiple tests.
 * @param {t_test*} test - The test to execute.
 */
void test_functions(t_test *test) {
    int num_threads = 4; // You can adjust the number of threads
    pthread_t threads[num_threads];
    thread_data thread_args[num_threads];
    int tests_per_thread = test->num_tests / num_threads;
    int remaining_tests = test->num_tests % num_threads;

    int total_pass_count = 0;
    int total_func1_better = 0;
    int total_func2_better = 0;

    // Create threads
    for (int i = 0; i < num_threads; i++) {
        thread_args[i].test = test;
        thread_args[i].start = i * tests_per_thread;
        thread_args[i].end = (i == num_threads - 1) ? (i + 1) * tests_per_thread + remaining_tests : (i + 1) * tests_per_thread;
        thread_args[i].pass_count = 0;
        thread_args[i].func1_better = 0;
        thread_args[i].func2_better = 0;

        pthread_create(&threads[i], NULL, test_functions_thread, (void *)&thread_args[i]);
    }

    // Wait for threads to complete
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
        total_pass_count += thread_args[i].pass_count;
        total_func1_better += thread_args[i].func1_better;
        total_func2_better += thread_args[i].func2_better;
    }

    printf("%s vs %s: %d/%d tests passed (%.2f%% correctness)\n",
           test->function1->name, test->function2->name, total_pass_count, test->num_tests, (total_pass_count / (double)test->num_tests) * 100);
    printf("%s was faster in %d cases\n", test->function1->name, total_func1_better);
    printf("%s was faster in %d cases\n", test->function2->name, total_func2_better);
}

/**
 * Generic function to handle result allocation.
 * @param {void*} input - The input to the operation.
 * @param {size_t} size - The size of the result.
 * @param {void (*)(void *, void *)} operation - The operation to perform.
 * @returns {void*} The allocated result.
 */
void *allocate_result(void *input, size_t size, void (*operation)(void *, void *)) {
    void *result = malloc(size);
    if (!result) {
        perror("Failed to allocate memory for result");
        exit(EXIT_FAILURE);
    }
    operation(result, input);
    return result;
}

/**
 * Multiply the input by 2.
 * @param {void*} result - The result to store the output.
 * @param {void*} input - The input to the operation.
 */
void multiply_by_2(void *result, void *input) {
    *(int *)result = *(int *)input * 2;
}

/**
 * Perform a bitwise shift left on the input.
 * @param {void*} result - The result to store the output.
 * @param {void*} input - The input to the operation.
 */
void bitwise_shift_left(void *result, void *input) {
    *(int *)result = *(int *)input << 1;
}

/**
 * Calculate the length of a string.
 * @param {void*} result - The result to store the output.
 * @param {void*} input - The input string.
 */
void calculate_strlen(void *result, void *input) {
    char *str = (char *)input;
    int i = 0;
    while (str[i]) i++;
    *(int *)result = i;
}

/**
 * Calculate the length of a string using an alternative method.
 * @param {void*} result - The result to store the output.
 * @param {void*} input - The input string.
 */
void calculate_strlen2(void *result, void *input) {
    char *ptr = (char *)input;
    while (*ptr++);
    *(int *)result = (ptr - (char *)input - 1);
}

/**
 * Multiply the input by 2.
 * @param {void*} input - The input to the operation.
 * @returns {void*} The result of the operation.
 */
void *testFunc1(void *input) {
    return allocate_result(input, sizeof(int), multiply_by_2);
}

/**
 * Perform a bitwise shift left on the input.
 * @param {void*} input - The input to the operation.
 * @returns {void*} The result of the operation.
 */
void *testFunc2(void *input) {
    return allocate_result(input, sizeof(int), bitwise_shift_left);
}

/**
 * Calculate the length of a string.
 * @param {char*} str - The input string.
 * @returns {int*} The length of the string.
 */
int *ft_strlen(char *str) {
    return allocate_result(str, sizeof(int), calculate_strlen);
}

/**
 * Calculate the length of a string using an alternative method.
 * @param {char*} str - The input string.
 * @returns {int*} The length of the string.
 */
int *ft_strlen2(char *str) {
    return allocate_result(str, sizeof(int), calculate_strlen2);
}

int main() {
    srand(time(NULL));

    t_function f1 = {"Multiply by 2", testFunc1, "Multiplies input by 2", 1, (char *[]){"int"}};
    t_function f2 = {"Bitwise Shift Left", testFunc2, "Shifts input left by 1 bit", 1, (char *[]){"int"}};
    t_function f3 = {"ft_strlen", ft_strlen, "Calculates the length of a string", 1, (char *[]){"string"}};
    t_function f4 = {"ft_strlen2", ft_strlen2, "Calculates the length of a string", 1, (char *[]){"string"}};
    t_test test = {&f1, &f2, NULL, "int", 100};
    t_test test2 = {&f3, &f4, NULL, "string", 100};

    test_functions(&test);
    test_functions(&test2);
    return 0;
}