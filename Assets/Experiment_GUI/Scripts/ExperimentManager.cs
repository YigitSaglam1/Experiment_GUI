using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class ExperimentManager : MonoBehaviour
{
    #region SINGLETON SETUP
    public static ExperimentManager Instance;
    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(this.gameObject);
        }
        else
        {
            Instance = this;
        }
    }
    #endregion

    [Header("References")]
    [SerializeField] private List<RectTransform> stimuliSpawnLocations = new List<RectTransform>();
    [SerializeField] private GameObject experimentPanel;
    [SerializeField] private GameObject menuPanel;
    [SerializeField] private TMP_Text infoText;
    [SerializeField] private GameObject stimuliPrefab;
    [SerializeField] private GameObject cuePrefab;

    private List<float> experimentParameters = new List<float>();
    private List<float> stimuliParameters = new List<float>();
    private List<GameObject> spawnedStimulus = new List<GameObject>();
    private List<GameObject> spawnedCue = new List<GameObject>();
    private ExperimentReport report;
    private bool isExperimentRunning;

    public void SetExperimentData(List<float> parameters)
    {
        experimentParameters.Clear();
        stimuliParameters.Clear();
        foreach (var stimulus in spawnedStimulus)
        {
            Destroy(stimulus);
        }
        foreach (var cue in spawnedCue)
        {
            Destroy(cue);
        }
        spawnedStimulus.Clear();
        spawnedCue.Clear();
        for (int i = 0; i < parameters.Count; i++)
        {
            if (i < 4) stimuliParameters.Add(parameters[i]);
            else experimentParameters.Add(parameters[i]);
        }
        StartExperimentProcedure();
    }
    private void StartExperimentProcedure()
    {
        //HANDLE UI HERE
        menuPanel.SetActive(false);
        experimentPanel.SetActive(true);
        report = new ExperimentReport();
        isExperimentRunning = true;
        StartCoroutine(ExperimentRoutine());
    }
    public IEnumerator ExperimentRoutine()
    {
        report.RecordExperimentStart();
        int experimentStartDelay = 5; //PRE-EXPERIMENT COUNTDOWN
        while (experimentStartDelay > 0)
        {
            StartCoroutine(InfoTextRoutine($"Experiment starting in {experimentStartDelay} seconds...", 1f));
            yield return new WaitForSeconds(1);
            experimentStartDelay--;
        }
        int firstSpawnIndex = 0;
        for (int i = 0; i < experimentParameters[5]; i++) //BLOCK REPEATER
        {
            report.RecordBlockStart(i);

            //CLEAR SITMULUS & CUE
            if (spawnedStimulus.Count > 0)
            {
                foreach (var stimulus in spawnedStimulus)
                {
                    Destroy(stimulus);
                }
                spawnedStimulus.Clear();
                foreach (var cue in spawnedCue)
                {
                    Destroy(cue);
                }
                spawnedCue.Clear();
            }
            //SPAWN STIMULUS & CUE
            int currentSpawnIndex = firstSpawnIndex;
            for (int j = 0; j < stimuliParameters.Count; j++)
            {
                if (currentSpawnIndex >= stimuliParameters.Count)
                {
                    GameObject stimulus = Instantiate(stimuliPrefab, stimuliSpawnLocations[currentSpawnIndex - stimuliParameters.Count]);
                    GameObject cue = Instantiate(cuePrefab, stimuliSpawnLocations[currentSpawnIndex - stimuliParameters.Count]);
                    stimulus.GetComponent<TrialBehaviour>().SetTrialParameters(stimuliParameters[j], experimentParameters[1]);
                    stimulus.SetActive(false);
                    cue.SetActive(false);
                    spawnedStimulus.Add(stimulus);
                    spawnedCue.Add(cue);
                }
                else
                {
                    GameObject stimulus = Instantiate(stimuliPrefab, stimuliSpawnLocations[currentSpawnIndex]);
                    GameObject cue = Instantiate(cuePrefab, stimuliSpawnLocations[currentSpawnIndex]);
                    stimulus.GetComponent<TrialBehaviour>().SetTrialParameters(stimuliParameters[j], experimentParameters[1]);
                    stimulus.SetActive(false);
                    cue.SetActive(false);
                    spawnedStimulus.Add(stimulus);
                    spawnedCue.Add(cue);
                }
                currentSpawnIndex++;
            }

            //TRIAL REPEATER
            for (int s = 0; s < spawnedStimulus.Count; s++)
            {
                for (int j = 0; j < experimentParameters[4]; j++)
                {
                    spawnedCue[s].SetActive(true);
                    yield return new WaitForSeconds(experimentParameters[0]); //CUE
                    spawnedCue[s].SetActive(false);
                    report.RecordStimulusStart(i, s, j, stimuliParameters[s]);
                    spawnedStimulus[s].SetActive(true);
                    yield return new WaitForSeconds(experimentParameters[1]); //STIMULUS
                    spawnedStimulus[s].SetActive(false);
                    report.RecordStimulusEnd(i, s, j, stimuliParameters[s]);

                    yield return new WaitForSeconds(experimentParameters[2]); //REST
                }
            }

            report.RecordBlockEnd(i);
            firstSpawnIndex++;

            if (i < experimentParameters[5] - 1) yield return new WaitForSeconds(experimentParameters[3]); //BLOCK REST
            else yield return null;
        }

        report.RecordExperimentEnd();
        StartCoroutine(InfoTextRoutine("Experiment completed successfully! Saving report...", 3f));
        yield return new WaitForSeconds(3);
        StartCoroutine(InfoTextRoutine("Thanks for your patience and contribution!", 7f));
        yield return new WaitForSeconds(7);
        StopExperimentProcedure(true);
    }
    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Escape) && isExperimentRunning)
        {
            StopExperimentProcedure(false);
        }
    }
    private void StopExperimentProcedure(bool isExperimentSuccesfullyDone)
    {
        if (!isExperimentRunning) return;
        isExperimentRunning = false;

        if (isExperimentSuccesfullyDone)
        {
            report.SaveToFile();
        }
        StopAllCoroutines();
        infoText.text = string.Empty;
        //HANDLE UI HERE
        menuPanel.SetActive(true);
        experimentPanel.SetActive(false);
    }
    private IEnumerator InfoTextRoutine(string message, float duration)
    {
        infoText.text = message;
        yield return new WaitForSeconds(duration);
        infoText.text = string.Empty;
    }
}
